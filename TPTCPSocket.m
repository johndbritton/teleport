//
//  TPTCPSocket.m
//  teleport
//
//  Created by JuL on Thu Jan 08 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPTCPSocket.h"

#include <fcntl.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>

#define CONNECTION_TIMEOUT 5.0
#define SEND_TIMEOUT 2.0

static void _cfsocketCallback(CFSocketRef inCFSocketRef, CFSocketCallBackType inType, CFDataRef inAddress, const void* inData, void* inContext);

@interface TPTCPSocket (Private)

- (void)_close:(BOOL)dropped;
- (OSStatus)_sendData:(CFDataRef)data;
- (void)_receivedData:(CFDataRef)data;

- (void)_connectionAcceptedWithNativeSocket:(int)nativeSocket;
- (void)_connectionAcceptedWithChildSocket:(TPTCPSocket*)childSocket;
- (void)_connectionFailed;
- (void)_connectionSucceeded;
- (void)_connectionClosed;

@end

@implementation TPTCPSocket

#define DEFAULTTARGET "255.255.255.255"
+ (BOOL)wakeUpHostWithMACAddress:(IOEthernetAddress)macAddress
{
	int sock;
	int optval = 1;
	int i, j, rc;
	char msg[1024];
	char *target = DEFAULTTARGET;
	int	 msglen = 0;
	struct sockaddr_in bcast;
	struct hostent *he;
	struct in_addr inaddr;
	short bport = htons(32767);

	for (i = 0; i < 6; i++) {
		msg[msglen++] = 0xff;
	}
	for (i = 0; i < 16; i++) {
//		memcpy(msg + msglen, macAddress.bytes, kIOEthernetAddressSize);
		for (j = 0; j < kIOEthernetAddressSize; j++) {
			msg[msglen++] = macAddress.bytes[j];
		}
	}
	
	if (!inet_aton(target, &inaddr)) {
		he = gethostbyname(target);
		inaddr = *(struct in_addr *)he->h_addr_list[0];
	}
	
	memset(&bcast, 0, sizeof(bcast));
	bcast.sin_family	  = AF_INET;
	bcast.sin_addr.s_addr = inaddr.s_addr;
	bcast.sin_port		  = bport;
	
	sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sock < 0) {
		printf ("Can't allocate socket\n");
		return NO;
	}
	if ((rc=setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &optval, sizeof(optval))) < 0) {
		printf ("Can't socket option SO_BROADCAST: rc = %d, errno=%s(%d)\n", rc, strerror(errno), errno);
		return NO;
	}
	sendto(sock, &msg, msglen, 0, (struct sockaddr *)&bcast, sizeof(bcast));
	close(sock);
	return YES;
}

- (instancetype) initWithDelegate:(id)delegate
{
	self = [super init];
	
	_delegate = delegate;
	_cfSocket = NULL;
	_runLoopRef = NULL;
	_sourceRef = NULL;
	_socketState = TPSocketDisconnectedState;
	_noDelay = NO;
	_lock = [[NSLock alloc] init];
	
	return self;
}

- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (id)delegate
{
	return _delegate;
}

- (void)setNoDelay:(BOOL)noDelay
{
	if(_noDelay != noDelay) {
		_noDelay = noDelay;
		
		[_lock lock];
		
		/* Setup socket flags */
		int socketOptionFlag = noDelay?1:0;
		int result = setsockopt(CFSocketGetNative(_cfSocket), IPPROTO_TCP, TCP_NODELAY, &socketOptionFlag, sizeof(int));
		if(result < 0) {
			DebugLog(@"error setting no delay");
			[_lock unlock];
			return;
		}
		
		if(noDelay) {
			socketOptionFlag = IPTOS_LOWDELAY | IPTOS_THROUGHPUT;
			int result = setsockopt(CFSocketGetNative(_cfSocket), IPPROTO_IP, IP_TOS, &socketOptionFlag, sizeof(socketOptionFlag));
			if(result < 0) {
				DebugLog(@"error setting low delay");
				[_lock unlock];
				return;
			}
		}
		else {
			/* Tweak for fast transfers */
//			int bufferSize = 32768;
//			int result = setsockopt(CFSocketGetNative(_cfSocket), SOL_SOCKET, SO_SNDBUF, &bufferSize, sizeof(int));
//			if(result < 0) {
//				DebugLog(@"error setting send buffer");
//				[_lock unlock];
//				return;
//			}
//			
//			result = setsockopt(CFSocketGetNative(_cfSocket), SOL_SOCKET, SO_RCVBUF, &bufferSize, sizeof(int));
//			if(result < 0) {
//				DebugLog(@"error setting receive buffer");
//				[_lock unlock];
//				return;
//			}
		}
		
		[_lock unlock];
	}
}
		
- (BOOL)_setupSocket
{
	if(_cfSocket == NULL) {
		DebugLog(@"cfSocket is NULL");
		return NO;
	}
	
	/* Setup socket flags */
	int socketOptionFlag = 1;
	int result = setsockopt(CFSocketGetNative(_cfSocket), SOL_SOCKET, SO_REUSEADDR, &socketOptionFlag, sizeof(int));
	if(result < 0) {
		DebugLog(@"error setting reusability of address");
		return NO;
	}
	
	[self _setRunLoop:CFRunLoopGetCurrent()];
	
	return YES;
}

- (BOOL)listenOnPort:(int*)port tries:(int)tries
{
	int currentPort = *port;
	int currentTry = tries;
	
	while(--currentTry) {
		if([self listenOnPort:currentPort])
			break;
		else {
			[self _close:NO];
			currentPort++;
		}
	}
	
	if(currentTry > 0) {
		*port = currentPort;
		return YES;
	}
	else
		return NO;
}

- (BOOL)listenOnPort:(int)port
{
	OSStatus err;
	
	/* Setup context */
	CFSocketContext socketContext;
	bzero(&socketContext, sizeof(CFSocketContext));
	socketContext.info = (__bridge void *)(self);
	
	/* Create socket */
	_cfSocket = CFSocketCreate(kCFAllocatorDefault,
							  AF_INET, 
							  SOCK_STREAM, 
							  IPPROTO_TCP, 
							  kCFSocketAcceptCallBack, 
							  &_cfsocketCallback, 
							  &socketContext
							  );

	if(![self _setupSocket])
		return NO;
	
	/* Setup struct sockaddr */
	struct sockaddr_in address;
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	address.sin_port = htons(port);
	
	CFDataRef addr = CFDataCreate(kCFAllocatorDefault, (void*)&address, sizeof(struct sockaddr_in));
	if((err = CFSocketSetAddress(_cfSocket, addr)) != kCFSocketSuccess) {
		CFRelease(addr);
		DebugLog(@"listen error: %d", errno);
		return NO;
	}
	
	CFRelease(addr);
	
#if DEBUG_SOCKET
	DebugLog(@"%@ listening on port %d", self, port);
#endif
	
	_socketState = TPSocketListeningState;
	
	return YES;
}

- (BOOL)connectToHost:(NSString*)host onPort:(int)port
{
	DebugLog(@"connect to %@ on port %d", host, port);
	
	if(host == nil) {
		NSLog(@"trying to connect to nil host");
		return NO;
	}
	
	/* Setup context */
	CFSocketContext socketContext;
	bzero(&socketContext, sizeof(CFSocketContext));
	socketContext.info = (__bridge void *)(self);
	
	/* Create socket */
	_cfSocket = CFSocketCreate(kCFAllocatorDefault,
							  PF_INET, 
							  SOCK_STREAM, 
							  IPPROTO_TCP, 
							  kCFSocketDataCallBack|kCFSocketConnectCallBack|kCFSocketWriteCallBack,
							  &_cfsocketCallback, 
							  &socketContext
							  );
	
	if(![self _setupSocket])
		return NO;
	
	/* Auto re-enable callbacks */
	CFOptionFlags socketFlags = CFSocketGetSocketFlags(_cfSocket);
	socketFlags |= kCFSocketAutomaticallyReenableDataCallBack;
	CFSocketSetSocketFlags(_cfSocket, socketFlags);
	
	/* Setup struct sockaddr */
	struct sockaddr_in address;
	address.sin_family = AF_INET;
#if LEGACY_BUILD
	struct hostent * hp = gethostbyname([host cString]);
#else
	struct hostent * hp = gethostbyname([host cStringUsingEncoding:NSASCIIStringEncoding]);
#endif
	if(hp == 0)
		return NO;
	bcopy((char *)hp->h_addr,(char *)&address.sin_addr, hp->h_length);
	address.sin_port = htons(port);
	
	/* Connect */
	CFDataRef addr = CFDataCreate(kCFAllocatorDefault, (void*)&address, sizeof(struct sockaddr_in));
	CFSocketError socketError = CFSocketConnectToAddress(_cfSocket, addr, CONNECTION_TIMEOUT);
	if (socketError != kCFSocketSuccess) {
		if(socketError == kCFSocketError) {
			int err = errno;
			DebugLog(@"Connection failed with errno: %d (%s)", err, strerror(err));
		} else if (socketError == kCFSocketTimeout) {
			DebugLog(@"Connection timeout.");
		}

		if(addr != NULL) {
			CFRelease(addr);
		}
		[self _close:NO];
		return NO;
	}

	if(addr != NULL) {
		CFRelease(addr);
	}

#if DEBUG_SOCKET
	DebugLog(@"%@ connecting to host %@ port %d", self, host, port);
#endif
	_socketState = TPSocketConnectingState;

	return YES;
}

- (void)setNativeSocket:(CFSocketNativeHandle)native
{
	/* Setup context */
	CFSocketContext socketContext;
	bzero(&socketContext, sizeof(CFSocketContext));
	socketContext.info = (__bridge void *)(self);
	
	/* Create socket from native */
	_cfSocket = CFSocketCreateWithNative(kCFAllocatorDefault, 
										native, 
										kCFSocketDataCallBack|kCFSocketWriteCallBack, 
										&_cfsocketCallback, 
										&socketContext
										);
	
	if(![self _setupSocket])
		return;
	
	/* Auto re-enable callbacks */
	CFOptionFlags socketFlags = CFSocketGetSocketFlags(_cfSocket);
	socketFlags |= kCFSocketAutomaticallyReenableDataCallBack;
	CFSocketSetSocketFlags(_cfSocket, socketFlags);
	
	_socketState = TPSocketConnectedState;
}

- (void)_setRunLoop:(CFRunLoopRef)runLoopRef
{
	[_lock lock];
	
	//DebugLog(@"socket: %@ _setRunLoop: %@ _runLoop: %@ _sourceRef: %@ current: %@", self, runLoopRef, _runLoopRef, _sourceRef, CFRunLoopGetCurrent());
	
	if(runLoopRef != NULL && _sourceRef == NULL && _cfSocket != NULL)
		_sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _cfSocket, 0);
	else if(runLoopRef != _runLoopRef && _runLoopRef != NULL && _sourceRef != NULL) {
		//DebugLog(@"willRemoveSource");
		CFRunLoopRemoveSource(_runLoopRef, _sourceRef, kCFRunLoopCommonModes);
		//DebugLog(@"didRemoveSource");
	}
	
	//DebugLog(@"_sourceRef: %@", _sourceRef);
	
	_runLoopRef = runLoopRef;
	
	if(runLoopRef != NULL && _sourceRef != NULL) {
		CFRunLoopAddSource(runLoopRef, _sourceRef, kCFRunLoopCommonModes);
		//DebugLog(@"adding source %@ to runloop %@ in mode %@", _sourceRef, runLoopRef, kCFRunLoopCommonModes);
	}
	else if(runLoopRef == NULL && _sourceRef != NULL) {
		CFRelease(_sourceRef);
		_sourceRef = NULL;
	}
	
	[_lock unlock];
}

- (void)dealloc
{
	[self close];
}

- (NSString*)_stringAddressFromCFData:(CFDataRef)dataRef
{
	char buffer[256];
	
	if(dataRef == NULL)
		return nil;
	
	struct sockaddr * socketAddress = (struct sockaddr *)CFDataGetBytePtr(dataRef);

	if(socketAddress->sa_family != AF_INET)
		NSLog(@"warning: address not AF_INET");

	if(inet_ntop(AF_INET, &((struct sockaddr_in *)socketAddress)->sin_addr, buffer, sizeof(buffer))) {
#if LEGACY_BUILD
		return [NSString stringWithCString:buffer];
#else
		return @(buffer);
#endif		
	}
	
	return nil;
}

- (NSString*)localAddress
{
	[_lock lock];
	CFDataRef dataRef = CFSocketCopyAddress(_cfSocket);
	[_lock unlock];
	
	if(dataRef != NULL) {
		NSString * localAddress = [self _stringAddressFromCFData:dataRef];
		CFRelease(dataRef);
		return localAddress;
	}
	else
		return nil;
}

- (NSString*)remoteAddress
{
	[_lock lock];
	CFDataRef dataRef = CFSocketCopyPeerAddress(_cfSocket);
	[_lock unlock];
	
	if(dataRef != NULL) {
		NSString * localAddress = [self _stringAddressFromCFData:dataRef];
		CFRelease(dataRef);
		return localAddress;
	}
	else
		return nil;
}

- (CFSocketNativeHandle)nativeHandle
{
	return CFSocketGetNative(_cfSocket);
}

- (BOOL)sendData:(NSData*)data
{
#if DEBUG_SOCKET
	DebugLog(@"%@ sending data (%d)", self, [data length]);
#endif
	
	BOOL result = ([self _sendData:(CFDataRef)data] == noErr);
	
#if DEBUG_SOCKET
	DebugLog(@"%@ end sending data (%d): %d", self, [data length], result);
#endif
	
	return result;
}

- (OSStatus)_sendData:(CFDataRef)data
{
	[_lock lock];
	
	if(_cfSocket == NULL || !CFSocketIsValid(_cfSocket)) {
		[_lock unlock];
		return kCFSocketError;
	}
	
	CFSocketEnableCallBacks(_cfSocket, kCFSocketWriteCallBack);
	
	int retries = 10;
    SInt32 size = 0;
    CFSocketNativeHandle sock = CFSocketGetNative(_cfSocket);
    const uint8_t * dataptr = CFDataGetBytePtr(data);
    SInt32 datalen = CFDataGetLength(data);
	
	size = send(sock, dataptr, datalen, 0);
	while(size < datalen && retries--) {
		DebugLog(@"retrying send, sent size: %d", size);
		if(size > 0) {
			dataptr += size;
			datalen -= size;
		}
		size = send(sock, dataptr, datalen, 0);
		DebugLog(@"after retry size: %d", size);
	}
	
	[_lock unlock];
	
	if(retries <= 0) {
		NSLog(@"Unable to send data: %@", self);
		return kCFSocketError;
	}

	return noErr;
}

- (TPSocketState)socketState
{
	return _socketState;
}

- (void)close
{
	[self setDelegate:nil];
	
	if(_socketState == TPSocketDisconnectedState)
		return;
	
	[self _close:NO];
}

- (void)_close:(BOOL)dropped
{
	_socketState = TPSocketDisconnectedState;

#if DEBUG_SOCKET
	DebugLog(@"socket %@ %@", self, dropped?@"dropped":@"closed");
#endif

	if(_sourceRef != NULL) {
		[self _setRunLoop:NULL];
	}
	if(_cfSocket != NULL) {
		[_lock lock];
		CFSocketInvalidate(_cfSocket);
		CFRelease(_cfSocket);
		_cfSocket = NULL;
		[_lock unlock];
	}
}

- (void)_receivedData:(CFDataRef)data
{
	if([_delegate respondsToSelector:@selector(tcpSocket:gotData:)])
		[_delegate tcpSocket:self gotData:(__bridge NSData*)data];
}

- (void)_didSendData
{
#if DEBUG_SOCKET
	DebugLog(@"%@ data sent", self);
#endif
	
	if([_delegate respondsToSelector:@selector(tcpSocketDidSendData:)])
		[_delegate tcpSocketDidSendData:self];
}

- (void)_connectionAcceptedWithNativeSocket:(int)nativeSocket
{
	TPTCPSocket * childSocket = [[[self class] alloc] initWithDelegate:nil];
	[childSocket setNativeSocket:nativeSocket];
	[self _connectionAcceptedWithChildSocket:childSocket];
}

- (void)_connectionAcceptedWithChildSocket:(TPTCPSocket*)childSocket
{
	if([_delegate respondsToSelector:@selector(tcpSocket:connectionAccepted:)])
		[_delegate tcpSocket:self connectionAccepted:childSocket];
}

- (void)_connectionFailed
{
	[self _close:NO];
	
	if([_delegate respondsToSelector:@selector(tcpSocketConnectionFailed:)])
		[_delegate tcpSocketConnectionFailed:self];
}

- (void)_connectionSucceeded
{
	PRINT_ME;
	_socketState = TPSocketConnectedState;
	
	if([_delegate respondsToSelector:@selector(tcpSocketConnectionSucceeded:)])
		[_delegate tcpSocketConnectionSucceeded:self];
}

- (void)_connectionClosed
{
	if(_socketState == TPSocketDisconnectedState)
		return;
	
	[self _close:YES];

	// keep a strong reference to prevent delegate(i.e. connection) from dealloc immediately.
	id delegate = _delegate;
	if([delegate respondsToSelector:@selector(tcpSocketConnectionClosed:)])
		[delegate tcpSocketConnectionClosed:self];
}

@end

void _cfsocketCallback(CFSocketRef inCFSocketRef, CFSocketCallBackType inType, CFDataRef inAddress, const void* inData, void* inContext)
{
	TPTCPSocket * tcpSocket = (__bridge TPTCPSocket*)inContext;

	if(!tcpSocket)
		return;

	switch(inType)
	{
		case kCFSocketDataCallBack:
		{
			if(inData == NULL || CFDataGetLength((CFDataRef)inData) == 0)
				[tcpSocket _connectionClosed];
			else
				[tcpSocket _receivedData:(CFDataRef)inData];
			break;
		}
		case kCFSocketAcceptCallBack:
		{
			int native = *((int*)inData);
			[tcpSocket _connectionAcceptedWithNativeSocket:native];
			break;
		}	
		case kCFSocketConnectCallBack:
		{
			if(inData == NULL)
				[tcpSocket _connectionSucceeded];
			else
				[tcpSocket _connectionFailed];
			break;
		}	
		case kCFSocketWriteCallBack:
		{
			[tcpSocket _didSendData];
			break;
		}
//		case kCFSocketWriteCallBack:
//		{
//			[tcpSocket _becameWritable];
//		}
		default:
			break;
	}
}

