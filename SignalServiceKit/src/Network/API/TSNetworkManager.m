//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSNetworkManager.h"
#import "AppContext.h"
#import "NSURLSessionDataTask+StatusCode.h"
#import "OWSSignalService.h"
#import "TSAccountManager.h"
#import "TSVerifyCodeRequest.h"
#import <AFNetworking/AFNetworking.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NSString *const TSNetworkManagerDomain = @"org.whispersystems.signal.networkManager";

BOOL IsNSErrorNetworkFailure(NSError *_Nullable error)
{
    return ([error.domain isEqualToString:TSNetworkManagerDomain] && error.code == 0);
}

@interface TSNetworkManager ()

typedef void (^failureBlock)(NSURLSessionDataTask *task, NSError *error);

@end

@implementation TSNetworkManager

#pragma mark Singleton implementation

+ (instancetype)sharedManager
{
    static TSNetworkManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}


- (instancetype)initDefault
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

#pragma mark Manager Methods

- (void)makeRequest:(TSRequest *)request
            success:(TSNetworkManagerSuccess)success
            failure:(TSNetworkManagerFailure)failure
{
    return [self makeRequest:request completionQueue:dispatch_get_main_queue() success:success failure:failure];
}

- (void)makeRequest:(TSRequest *)request
    completionQueue:(dispatch_queue_t)completionQueue
            success:(TSNetworkManagerSuccess)successBlock
            failure:(TSNetworkManagerFailure)failureBlock
{
    OWSAssert(request);
    OWSAssert(successBlock);
    OWSAssert(failureBlock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self makeRequestSync:request completionQueue:completionQueue success:successBlock failure:failureBlock];
    });
}

- (void)makeRequestSync:(TSRequest *)request
        completionQueue:(dispatch_queue_t)completionQueue
                success:(TSNetworkManagerSuccess)successBlock
                failure:(TSNetworkManagerFailure)failureBlock
{
    OWSAssert(request);
    OWSAssert(successBlock);
    OWSAssert(failureBlock);

    DDLogInfo(@"%@ Making request: %@", self.logTag, request);

    // TODO: Remove this logging when the call connection issues have been resolved.
    TSNetworkManagerSuccess success = ^(NSURLSessionDataTask *task, _Nullable id responseObject) {
        DDLogInfo(@"%@ AA request succeeded : %@", self.logTag, request);

        if (request.shouldHaveAuthorizationHeaders) {
            DDLogInfo(@"Dentro do if");
            [TSAccountManager.sharedInstance setIsDeregistered:NO];
        }

        DDLogInfo(@"Antes do successBlock");
        successBlock(task, responseObject);
        DDLogInfo(@"Depois do successBlock");

        [OutageDetection.sharedManager reportConnectionSuccess];
    };
    TSNetworkManagerFailure failure = [TSNetworkManager errorPrettifyingForFailureBlock:failureBlock request:request];

    AFHTTPSessionManager *sessionManager = [OWSSignalService sharedInstance].signalServiceSessionManager;
    // [OWSSignalService signalServiceSessionManager] always returns a new instance of
    // session manager, so its safe to reconfigure it here.
    sessionManager.completionQueue = completionQueue;
    
    if ([request isKindOfClass:[TSVerifyCodeRequest class]]) {
        // We plant the Authorization parameter ourselves, no need to double add.
        [sessionManager.requestSerializer
            setAuthorizationHeaderFieldWithUsername:((TSVerifyCodeRequest *)request).numberToValidate
                                           password:[request.parameters objectForKey:@"AuthKey"]];
        NSMutableDictionary *parameters = [request.parameters mutableCopy];
        [parameters removeObjectForKey:@"AuthKey"];
        [sessionManager PUT:request.URL.absoluteString parameters:parameters success:success failure:failure];
    } else {
        if (request.shouldHaveAuthorizationHeaders) {
            [sessionManager.requestSerializer
                setAuthorizationHeaderFieldWithUsername:[TSAccountManager localNumber]
                                               password:[TSAccountManager serverAuthToken]];
        }

        if ([request.HTTPMethod isEqualToString:@"GET"]) {
            [sessionManager GET:request.URL.absoluteString
                     parameters:request.parameters
                       progress:nil
                        success:success
                        failure:failure];
        } else if ([request.HTTPMethod isEqualToString:@"POST"]) {
            [sessionManager POST:request.URL.absoluteString
                      parameters:request.parameters
                        progress:nil
                         success:success
                         failure:failure];
        } else if ([request.HTTPMethod isEqualToString:@"PUT"]) {
            [sessionManager PUT:request.URL.absoluteString
                     parameters:request.parameters
                        success:success
                        failure:failure];
        } else if ([request.HTTPMethod isEqualToString:@"DELETE"]) {
            [sessionManager DELETE:request.URL.absoluteString
                        parameters:request.parameters
                           success:success
                           failure:failure];
        } else {
            DDLogError(@"Trying to perform HTTP operation with unknown verb: %@", request.HTTPMethod);
        }
    }
}

+ (failureBlock)errorPrettifyingForFailureBlock:(failureBlock)failureBlock request:(TSRequest *)request
{
    OWSAssert(failureBlock);
    OWSAssert(request);

    return ^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull networkError) {
      NSInteger statusCode = [task statusCode];

      [OutageDetection.sharedManager reportConnectionFailure];

      NSError *error = [self errorWithHTTPCode:statusCode
                                   description:nil
                                 failureReason:nil
                            recoverySuggestion:nil
                                 fallbackError:networkError];

      switch (statusCode) {
          case 0: {
              DDLogWarn(@"The network request failed because of a connectivity error: %@", request);
              failureBlock(task,
                  [self errorWithHTTPCode:statusCode
                              description:NSLocalizedString(@"ERROR_DESCRIPTION_NO_INTERNET",
                                              @"Generic error used whenever Signal can't contact the server")
                            failureReason:networkError.localizedFailureReason
                       recoverySuggestion:NSLocalizedString(@"NETWORK_ERROR_RECOVERY", nil)
                            fallbackError:networkError]);
              break;
          }
          case 400: {
              DDLogError(@"The request contains an invalid parameter : %@, %@", networkError.debugDescription, request);

              [TSAccountManager.sharedInstance setIsDeregistered:YES];

              failureBlock(task, error);
              break;
          }
          case 401: {
              DDLogError(@"The server returned an error about the authorization header: %@, %@",
                  networkError.debugDescription,
                  request);
              failureBlock(task, error);
              break;
          }
          case 403: {
              DDLogError(
                  @"The server returned an authentication failure: %@, %@", networkError.debugDescription, request);
              failureBlock(task, error);
              break;
          }
          case 404: {
              DDLogError(@"The requested resource could not be found: %@, %@", networkError.debugDescription, request);
              failureBlock(task, error);
              break;
          }
          case 411: {
              DDLogInfo(@"Multi-device pairing: %zd, %@, %@", statusCode, networkError.debugDescription, request);
              failureBlock(task,
                           [self errorWithHTTPCode:statusCode
                                       description:NSLocalizedString(@"MULTIDEVICE_PAIRING_MAX_DESC", nil)
                                     failureReason:networkError.localizedFailureReason
                                recoverySuggestion:NSLocalizedString(@"MULTIDEVICE_PAIRING_MAX_RECOVERY", nil)
                                     fallbackError:networkError]);
              break;
          }
          case 413: {
              DDLogWarn(@"Rate limit exceeded: %@", request);
              failureBlock(task,
                           [self errorWithHTTPCode:statusCode
                                       description:NSLocalizedString(@"REGISTRATION_ERROR", nil)
                                     failureReason:networkError.localizedFailureReason
                                recoverySuggestion:NSLocalizedString(@"REGISTER_RATE_LIMITING_BODY", nil)
                                     fallbackError:networkError]);
              break;
          }
          case 417: {
              DDLogWarn(@"The number is already registered on a relay. Please unregister there first: %@", request);
              failureBlock(task,
                           [self errorWithHTTPCode:statusCode
                                       description:NSLocalizedString(@"REGISTRATION_ERROR", nil)
                                     failureReason:networkError.localizedFailureReason
                                recoverySuggestion:NSLocalizedString(@"RELAY_REGISTERED_ERROR_RECOVERY", nil)
                                     fallbackError:networkError]);
              break;
          }
          case 422: {
              DDLogError(@"The registration was requested over an unknown transport: %@, %@",
                  networkError.debugDescription,
                  request);
              failureBlock(task, error);
              break;
          }
          default: {
              DDLogWarn(@"Unknown error: %zd, %@, %@", statusCode, networkError.debugDescription, request);
              failureBlock(task, error);
              break;
          }
      }
    };
}

+ (NSError *)errorWithHTTPCode:(NSInteger)code
                   description:(NSString *)description
                 failureReason:(NSString *)failureReason
            recoverySuggestion:(NSString *)recoverySuggestion
                 fallbackError:(NSError *_Nonnull)fallbackError {
    if (!description) {
        description = fallbackError.localizedDescription;
    }
    if (!failureReason) {
        failureReason = fallbackError.localizedFailureReason;
    }
    if (!recoverySuggestion) {
        recoverySuggestion = fallbackError.localizedRecoverySuggestion;
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    if (description) {
        [dict setObject:description forKey:NSLocalizedDescriptionKey];
    }
    if (failureReason) {
        [dict setObject:failureReason forKey:NSLocalizedFailureReasonErrorKey];
    }
    if (recoverySuggestion) {
        [dict setObject:recoverySuggestion forKey:NSLocalizedRecoverySuggestionErrorKey];
    }

    NSData *failureData = fallbackError.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];

    if (failureData) {
        [dict setObject:failureData forKey:AFNetworkingOperationFailingURLResponseDataErrorKey];
    }

    return [NSError errorWithDomain:TSNetworkManagerDomain code:code userInfo:dict];
}

@end
