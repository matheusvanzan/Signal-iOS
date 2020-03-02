//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#ifndef TextSecureKit_Constants_h
#define TextSecureKit_Constants_h

typedef NS_ENUM(NSInteger, TSWhisperMessageType) {
    TSUnknownMessageType            = 0,
    TSEncryptedWhisperMessageType   = 1,
    TSIgnoreOnIOSWhisperMessageType = 2, // on droid this is the prekey bundle message irrelevant for us
    TSPreKeyWhisperMessageType      = 3,
    TSUnencryptedWhisperMessageType = 4,
};

#pragma mark Server Address

#define textSecureHTTPTimeOut 10

#define kLegalTermsUrlString @"https://signal.org/legal/"
//#define SHOW_LEGAL_TERMS_LINK

//#ifndef DEBUG

// EBChat 2 - Domain
//#define textSecureWebSocketAPI @"wss://web-msg.eb.mil.br/v1/websocket/"
//#define textSecureServerURL @"https://web-msg.eb.mil.br/"
//#define textSecureCDNServerURL @"https://cdn.signal.org"
//#define textSecureServiceReflectorHost @"web-msg.eb.mil.br"
//#define textSecureCDNReflectorHost @"web-msg.eb.mil.br"

// EBChat 2 - IP
#define textSecureDomainName @"10.166.66.47"
#define textSecureWebSocketAPI @"wss://10.166.66.47/v1/websocket/"
#define textSecureServerURL @"https://10.166.66.47/"
#define textSecureCDNServerURL @"https://10.166.66.47/"
#define textSecureServiceReflectorHost @"10.166.66.47"
#define textSecureCDNReflectorHost @"10.166.66.47"

// Production
//#define textSecureWebSocketAPI @"wss://textsecure-service.whispersystems.org/v1/websocket/"
//#define textSecureServerURL @"https://textsecure-service.whispersystems.org/"
//#define textSecureCDNServerURL @"https://cdn.signal.org"
//#define textSecureServiceReflectorHost @"textsecure-service-reflected.whispersystems.org"
//#define textSecureCDNReflectorHost @"textsecure-service-reflected.whispersystems.org"

//#else
//
//// Staging
//#define textSecureWebSocketAPI @"wss://textsecure-service-staging.whispersystems.org/v1/websocket/"
//#define textSecureServerURL @"https://textsecure-service-staging.whispersystems.org/"
//#define textSecureCDNServerURL @"https://cdn-staging.signal.org"
//#define textSecureServiceReflectorHost @"meek-signal-service-staging.appspot.com";
//#define textSecureCDNReflectorHost @"meek-signal-cdn-staging.appspot.com";
//
//#endif

#define textSecureAccountsAPI @"v1/accounts"
#define textSecureAttributesAPI @"/attributes/"

#define textSecureMessagesAPI @"v1/messages/"
#define textSecureKeysAPI @"v2/keys"
#define textSecureSignedKeysAPI @"v2/keys/signed"
#define textSecureDirectoryAPI @"v1/directory"
#define textSecureAttachmentsAPI @"v1/attachments"
#define textSecureDeviceProvisioningCodeAPI @"v1/devices/provisioning/code"
#define textSecureDeviceProvisioningAPIFormat @"v1/provisioning/%@"
#define textSecureDevicesAPIFormat @"v1/devices/%@"
#define textSecureProfileAPIFormat @"v1/profile/%@"
#define textSecureSetProfileNameAPIFormat @"v1/profile/name/%@"
#define textSecureProfileAvatarFormAPI @"v1/profile/form/avatar"
#define textSecure2FAAPI @"/v1/accounts/pin"

#define SignalApplicationGroup @"group.br.mil.eb.ccomsex.signal"

#endif
