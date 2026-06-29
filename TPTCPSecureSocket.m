//
//  TPTCPSecureSocket.m
//  SecureMessaging
//
//  Created by JuL on 03/04/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import "TPTCPSecureSocket.h"

@interface TPTCPSocket (Private)

- (void)_close:(BOOL)dropped;
- (OSStatus)_sendData:(CFDataRef)data;
- (void)_receivedData:(CFDataRef)data;

@property (nonatomic, readonly, strong) Class _childSocketClass;
- (void)_connectionAcceptedWithNativeSocket:(int)nativeSocket;
- (void)_connectionAcceptedWithChildSocket:(TPTCPSocket*)childSocket;
- (void)_connectionFailed;
- (void)_connectionSucceeded;
- (void)_connectionClosed;

@end

@interface TPTCPSecureSocket ()

@property (nonatomic, strong) NSMutableSet * childSockets;

- (BOOL)_activateSSLWithParentSocket:(TPTCPSecureSocket*)parentSocket;
- (BOOL)_setupSSLContextForServer:(BOOL)server;
@property (nonatomic, readonly) SSLSessionState _setupSSLSession;
@property (nonatomic, readonly) SSLSessionState _startSSLSession;

@property (nonatomic, readonly) BOOL _isServer;

- (void)_sslFailed;
- (void)_sslSucceeded;

- (OSStatus)_sslReadToData:(void*)data length:(size_t*)dataLength;
- (OSStatus)_sslSendData:(const void*)data length:(size_t*)length;

@end

OSStatus _TPTCPSecureSocketRead(SSLConnectionRef connection, void *data, size_t *dataLength);
OSStatus _TPTCPSecureSocketWrite(SSLConnectionRef connection, const void *data, size_t *dataLength);

@implementation TPTCPSecureSocket

#pragma mark -
#pragma mark TPTCPSocket overdrives

- (instancetype) initWithDelegate:(id)delegate
{
	self = [super initWithDelegate:delegate];
	
	_secureSocketState = TPSecureSocketNormalState;
	_encryptedDataRef = NULL;
	_contextRef = NULL;
	_enableEncryption = YES;
	_sslLock = [[NSLock alloc] init];
	_childSockets = [[NSMutableSet alloc] init];
	
	return self;
}


- (void)setEnableEncryption:(BOOL)enableEncryption
{
	_enableEncryption = enableEncryption;
}

//- (BOOL)listenOnPort:(int*)port tries:(int)tries
//{
//	if(![self _activateSSLForServer:YES])
//		return NO;
//	else
//		return [super listenOnPort:port tries:tries];
//}

- (BOOL)_activateSSLWithParentSocket:(TPTCPSecureSocket*)parentSocket
{
	BOOL result = NO;
	
	_parentSocket = parentSocket;
	
	if(_contextRef == NULL)
		result = [self _setupSSLContextForServer:[self _isServer]];
	else
		result = YES;
	
	if(result && [self socketState] == TPSocketConnectedState) {
		SSLSessionState sessionState = [self _setupSSLSession];
		result = (sessionState == kSSLConnected) || (sessionState == kSSLHandshake);
	}
	
	return result;
}

- (BOOL)_setupSSLContextForServer:(BOOL)server
{
	OSStatus err;
	
	//	DebugLog(@"%p is %@", self, server?@"server":@"client");
	
	[_sslLock lock];
	
	if((err = SSLNewContext([self _isServer], &_contextRef)) != noErr) {
		NSLog(@"Unable to create SSL context: %d", err);
		[_sslLock unlock];
		return NO;
	}
	
	if((err = SSLSetIOFuncs(_contextRef, _TPTCPSecureSocketRead, _TPTCPSecureSocketWrite)) != noErr) {
		NSLog(@"Unable to set IO functions: %d", err);
		[_sslLock unlock];
		return NO;
	}
	
	if((err = SSLSetEnableCertVerify(_contextRef, false)) != noErr) {
		NSLog(@"Unable to set off cert verify: %d", err);
		[_sslLock unlock];
		return NO;
	}
	
	if((err = SSLSetClientSideAuthenticate(_contextRef, kAlwaysAuthenticate)) != noErr) {
		NSLog(@"Unable to set client side authenticate: %d", err);
		[_sslLock unlock];
		return NO;
	}
	
	[_sslLock unlock];
	
	return YES;
}

- (SSLSessionState)_setupSSLSession
{
	PRINT_ME_IF(DEBUG_SOCKET);
	SSLSessionState sessionState = [self _startSSLSession];
	switch(sessionState) {
		case kSSLConnected:
			[self _sslSucceeded];
			break;
		case kSSLHandshake:
			_secureSocketState = TPSecureSocketHandshakingState;
			break;
		default:
			[self _close:NO];
			break;
	}
	
	return sessionState;
}

- (SSLSessionState)_startSSLSession
{
	PRINT_ME_IF(DEBUG_SOCKET);
	OSStatus err;
	
	[_sslLock lock];
	
	if((err = SSLSetConnection(_contextRef, (__bridge SSLConnectionRef)self)) != noErr) {
		NSLog(@"Unable to set SSL connection: %d", err);
		[_sslLock unlock];
		return kSSLAborted;
	}
	
	if(![_delegate respondsToSelector:@selector(tcpSecureSocketCopyIdentity:)]) {
		NSLog(@"Unable to get identity from delegate %@", _delegate);
		[_sslLock unlock];
		return kSSLAborted;
	}
	
	SecIdentityRef identity = [_delegate tcpSecureSocketCopyIdentity:self];
	if(identity == NULL) {
		NSLog(@"Got NULL identity from delegate %@", _delegate);
		[_sslLock unlock];
		return kSSLAborted;
	}
	
	CFArrayRef certificatesRef = CFArrayCreate(kCFAllocatorDefault, (const void**)&identity, 1, &kCFTypeArrayCallBacks);
	CFRelease(identity);
	
	if((err = SSLSetCertificate(_contextRef, certificatesRef)) != noErr) {
		NSLog(@"Unable to set certificate: %d", err);
		CFRelease(certificatesRef);
		[_sslLock unlock];
		return kSSLAborted;
	}
	
	CFRelease(certificatesRef);
	
	_encryptedDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
	
	err = SSLHandshake(_contextRef);
//	DebugLog(@"%p start handshaking", self);
	
	[_sslLock unlock];
	
	if(err == noErr) {
		return kSSLConnected;
	}
	else if(err != errSSLWouldBlock) {
		NSLog(@"Unable to handshake: %d", err);
		return kSSLAborted;
	}
	else
		return kSSLHandshake;
}

- (BOOL)_isServer
{
	return (_parentSocket != nil);
}

- (void)_connectionAcceptedWithChildSocket:(TPTCPSocket*)childSocket
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	TPTCPSecureSocket * secureChildSocket = (TPTCPSecureSocket*)childSocket;
	BOOL enableEncryption = YES;
	if([_delegate respondsToSelector:@selector(tcpSecureSocketShouldEnableEncryption:)]) {
		enableEncryption = [_delegate tcpSecureSocketShouldEnableEncryption:secureChildSocket];
	}

	[secureChildSocket setEnableEncryption:enableEncryption];
	
	if(enableEncryption) {
		[_childSockets addObject:secureChildSocket];
		[secureChildSocket setDelegate:[self delegate]];
		[secureChildSocket _activateSSLWithParentSocket:self];
		 // balanced with release in _sslSucceeded
	}
	else {
		[super _connectionAcceptedWithChildSocket:childSocket];
	}
}

- (void)_connectionSucceeded
{
	PRINT_ME_IF(DEBUG_SOCKET);

	if(_enableEncryption) {
		_socketState = TPSocketConnectedState;
		[self _activateSSLWithParentSocket:nil];
	}
	else {
		[super _connectionSucceeded];
	}
}

- (void)_connectionClosed
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	if(_enableEncryption) {
		if(_socketState == TPSocketDisconnectedState)
			return;
		
		if(_secureSocketState == TPSecureSocketNormalState)
			[super _connectionClosed];
		else
			[self _sslFailed];
	}
	else {
		[super _connectionClosed];
	}
}

- (void)_sslFailed
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	if([_delegate respondsToSelector:@selector(tcpSocketSecureConnectionFailed:)])
		[_delegate tcpSocketSecureConnectionFailed:self];
	
	[self _close:NO];
	
}

- (void)_sslSucceeded
{
	PRINT_ME_IF(DEBUG_SOCKET);
	_secureSocketState = TPSecureSocketNormalState;
	
	if([self _isServer]) {
		[_parentSocket->_childSockets removeObject:self];
		
		if([_delegate respondsToSelector:@selector(tcpSocket:secureConnectionAccepted:)])
			[_delegate tcpSocket:_parentSocket secureConnectionAccepted:self];
	}
	else {
		if([_delegate respondsToSelector:@selector(tcpSocketSecureConnectionSucceeded:)])
			[_delegate tcpSocketSecureConnectionSucceeded:self];
	}
	
	if([self _isServer]) {
	}
}

- (BOOL)sendData:(NSData*)data
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	if(_enableEncryption) {
		size_t dataLength = [data length];
		size_t dataProcessed = 0;
		
		while(dataProcessed < dataLength) {
			size_t processed = 0;
			OSStatus err;
			[_sslLock lock];
			if((err = SSLWrite(_contextRef, ([data bytes] + dataProcessed), (dataLength - dataProcessed), &processed)) != noErr) {
				NSLog(@"SSL unable to write data: %d", err);
				[_sslLock unlock];
				return NO;
			}
			[_sslLock unlock];
			dataProcessed += processed;
		}
		
		return YES;		
	}
	else {
		return [super sendData:data];
	}
}

- (void)_receivedData:(CFDataRef)data
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	if(_enableEncryption) {
		SSLSessionState sessionState;
		[_sslLock lock];
		SSLGetSessionState(_contextRef, &sessionState);
		[_sslLock unlock];

		CFDataAppendBytes(_encryptedDataRef, CFDataGetBytePtr(data), CFDataGetLength(data));
		
#if DEBUG_SOCKET
		DebugLog(@"%p receivedData(%d) state=%d", self, CFDataGetLength(data), sessionState);
#endif
		
		switch(sessionState) {
			case kSSLIdle:
			case kSSLHandshake:
			{
				[_sslLock lock];
				OSStatus err = SSLHandshake(_contextRef);
				[_sslLock unlock];

				//			DebugLog(@"%p handshake", self);
				
				if(err != noErr) {
					if(err != errSSLWouldBlock) {
						NSLog(@"Unable to handshake: %d", err);
						[self _sslFailed];
					}
					break;
				}
				else {
					DebugLog(@"%p handshake success!", self);
					switch(_secureSocketState) {
						case TPSecureSocketNormalState:
							NSLog(@"Handshaking but normal socket state!");
							break;
						case TPSecureSocketHandshakingState:
							[self _sslSucceeded];
							break;
					}
				}
			}
			case kSSLConnected:
			{
				CFMutableDataRef decryptedDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
				CFIndex index = CFDataGetLength(decryptedDataRef);
				
				OSStatus err = noErr;
				while(err == noErr) {
					size_t bufSize = 0;
					
					[_sslLock lock];
					if((err = SSLGetBufferedReadSize(_contextRef, &bufSize)) != noErr) {
						NSLog(@"Unable to get bufSize: %d", err);
						[_sslLock unlock];
						CFRelease(decryptedDataRef);
						[self _sslFailed];
						return;
					}
					
					if(bufSize == 0) {
						bufSize = 4096;
					}
					
					CFIndex dataLength = index + bufSize;
					CFDataSetLength(decryptedDataRef, dataLength);
					
					UInt8 * buffer = CFDataGetMutableBytePtr(decryptedDataRef);
					size_t processed = 0;
					err = SSLRead(_contextRef, buffer + index, bufSize, &processed);
					
					[_sslLock unlock];
					
					if(err != noErr && err != errSSLWouldBlock && err != errSSLClosedGraceful) {
						NSLog(@"Unable to read: %d", err);
						CFRelease(decryptedDataRef);
						[self _sslFailed];
						return;
					}
					
					if(processed < bufSize) {
						dataLength = index + processed;
						CFDataSetLength(decryptedDataRef, dataLength);
					}
					
					if(processed > 0) {
						index += processed;
					}
				}
				
				if(CFDataGetLength(decryptedDataRef) > 0) {
					[super _receivedData:decryptedDataRef];
				}
				CFRelease(decryptedDataRef);
				break;
			}
			case kSSLClosed:
			case kSSLAborted:
				NSLog(@"SSL received data with invalid session state: %d", sessionState);
				[self _sslFailed];
				break;
		}
	}
	else {
		[super _receivedData:data];
	}
}

- (void)_close:(BOOL)dropped
{
	if(_enableEncryption) {
		if(!dropped) {
			[_sslLock lock];
			SSLClose(_contextRef);
			[_sslLock unlock];
		}
		
		[super _close:dropped];
		
		SSLDisposeContext(_contextRef);
		_contextRef = NULL;
		
		if(_encryptedDataRef != NULL) {
			CFRelease(_encryptedDataRef);
			_encryptedDataRef = NULL;
		}
	}
	else {
		[super _close:dropped];
	}
}


#pragma mark -
#pragma mark Internal SSL Input/Output

- (OSStatus)_sslReadToData:(void*)data length:(size_t*)length
{
	PRINT_ME_IF(DEBUG_SOCKET);
	
	size_t askedSize = *length;
	*length = MIN(askedSize, CFDataGetLength(_encryptedDataRef));
	
	if(*length == 0) {
		return errSSLWouldBlock;
	}
	
	CFRange bytesRange = CFRangeMake(0, *length);
	CFDataGetBytes(_encryptedDataRef, bytesRange, data);
	CFDataDeleteBytes(_encryptedDataRef, bytesRange);
	
	if(askedSize > *length) {
		return errSSLWouldBlock;
	}
	
	return noErr;
}

- (OSStatus)_sslSendData:(const void*)data length:(size_t*)length
{
	PRINT_ME_IF(DEBUG_SOCKET);
	if(*length == 0) return noErr;
	CFDataRef dataRef = CFDataCreateWithBytesNoCopy(NULL, data, *length, kCFAllocatorNull);
	if(dataRef == NULL)
		return -1;
	OSStatus err = [self _sendData:dataRef];
	CFRelease(dataRef);
	return err;
}


#pragma mark -
#pragma mark SSL Stuff

- (SecCertificateRef)copyPeerCertificate
{
	PRINT_ME_IF(DEBUG_SOCKET);
	OSStatus err;
	CFArrayRef certsRef;
	
	[_sslLock lock];
	
#if LEGACY_BUILD
	err = SSLGetPeerCertificates(_contextRef, &certsRef);
#else
	err = SSLCopyPeerCertificates(_contextRef, &certsRef);
#endif
	
	[_sslLock unlock];
	
	if(err != noErr) {
		NSLog(@"Unable to get peer certificate: %d", err);
		return NULL;
	}
	
	if(CFArrayGetCount(certsRef) < 1) {
		NSLog(@"Unable to get peer certificate: %d", err);
		return NULL;
	}
	
	SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(certsRef, 0);
	CFRetain(cert);
	CFRelease(certsRef);
	
	return cert;
}

@end

OSStatus _TPTCPSecureSocketRead(SSLConnectionRef connection, void *data, size_t *dataLength)
{
	TPTCPSecureSocket * socket = (__bridge TPTCPSecureSocket*)connection;
	return [socket _sslReadToData:data length:dataLength];
}


OSStatus _TPTCPSecureSocketWrite(SSLConnectionRef connection, const void *data, size_t *dataLength)
{
	TPTCPSecureSocket * socket = (__bridge TPTCPSecureSocket*)connection;
	return [socket _sslSendData:data length:dataLength];
}
