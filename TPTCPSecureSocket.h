//
//  TPTCPSecureSocket.h
//  SecureMessaging
//
//  Created by JuL on 03/04/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import "TPTCPSocket.h"

typedef NS_ENUM(NSInteger, TPSecureSocketState) {
	TPSecureSocketNormalState,
	TPSecureSocketHandshakingState
} ;

@interface TPTCPSecureSocket : TPTCPSocket
{
	BOOL _enableEncryption;
	SSLContextRef _contextRef;
	TPSecureSocketState _secureSocketState;
	TPTCPSecureSocket * _parentSocket;
	NSLock * _sslLock;
	
	CFMutableDataRef _encryptedDataRef;
}

- (void)setEnableEncryption:(BOOL)enableEncryption;
@property (nonatomic, readonly) SecCertificateRef copyPeerCertificate;

@end

@interface NSObject (TPTCPSecureSocket_delegate)

- (SecIdentityRef)tcpSecureSocketCopyIdentity:(TPTCPSecureSocket*)tcpSocket;
- (BOOL)tcpSecureSocketShouldEnableEncryption:(TPTCPSecureSocket*)tcpSocket;
- (void)tcpSocketSecureConnectionSucceeded:(TPTCPSecureSocket*)tcpSocket;
- (void)tcpSocketSecureConnectionFailed:(TPTCPSecureSocket*)tcpSocket;
- (void)tcpSocket:(TPTCPSecureSocket*)listenSocket secureConnectionAccepted:(TPTCPSecureSocket*)childSocket;

@end
