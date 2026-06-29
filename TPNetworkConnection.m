//
//  TPNetworkConnection.m
//  teleport
//
//  Created by JuL on Mon Dec 29 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPNetworkConnection.h"
//#import "TPNetworkConnection_Private.h"
#import "TPPreferencesManager.h"
#import "TPTransfersManager.h"
#import "TPBezelController.h"
#import "TPHostsManager.h"
#import "TPLocalHost.h"
#import "TPTCPSecureSocket.h"
#import "TPMessage.h"

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

static NSString *interfaceNameForIPAddress(NSString *ipAddress) {
	struct ifaddrs *ifaddr, *ifa;
	char host[NI_MAXHOST];

	if (getifaddrs(&ifaddr) == -1) {
		perror("getifaddrs");
		return nil;
	}

	NSString *foundInterface = nil;

	for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
		if (!ifa->ifa_addr)
			continue;

		int family = ifa->ifa_addr->sa_family;
		void *addr = NULL;

		if (family == AF_INET) {
			// IPv4
			addr = &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr;
		} else if (family == AF_INET6) {
			// IPv6
			struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
			if (IN6_IS_ADDR_LINKLOCAL(&sin6->sin6_addr)) continue; // Skip link-local
			addr = &sin6->sin6_addr;
		} else {
			continue;
		}

		inet_ntop(family, addr, host, sizeof(host));
		if (ipAddress && strcmp(host, ipAddress.UTF8String) == 0) {
			foundInterface = [NSString stringWithUTF8String:ifa->ifa_name];
			break;
		}
	}

	freeifaddrs(ifaddr);
	return foundInterface;
}

@interface TPNetworkConnection (Internal)

@property (nonatomic, readonly) BOOL _sendPendingMessages;

@end

@implementation TPNetworkConnection

- (instancetype) initWithSocket:(TPTCPSocket*)socket
{
	self = [super init];
	
	_socket = socket;
	[_socket setDelegate:self];
	
	_networkInterfaceName = interfaceNameForIPAddress([_socket localAddress]);
	
	_connectedHost = nil;
	_capabilities = [[TPLocalHost localHost] capabilities];
	
	_delegate = nil;
	_msgBuffer = [[NSMutableData alloc] init];
	
	_pendingMessages = [[NSMutableArray alloc] init];
	
	DebugLog(@"init connection %@", self);
	
	return self;
}

- (void)dealloc
{
	[self disconnect];
	
	DebugLog(@"connection %@ dealloc", self);
	_delegate = nil;
	if([_socket delegate] == self) {
		[_socket setDelegate:nil];
	}
}

#if 0
- (id)retain
{
	DebugLog(@"retain connection %@ (%d>%d)", self, [self retainCount], [self retainCount]+1);
	return [super retain];
}

- (void)release
{
	DebugLog(@"release connection %@ (%d>%d)", self, [self retainCount], [self retainCount]-1);
	[super release];
}

- (id)autorelease
{
	DebugLog(@"autorelease connection %@ (%d)", self, [self retainCount]);
	return [super autorelease];
}
#endif

- (TPTCPSocket*)socket
{
	return _socket;
}

- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (id)delegate
{
	return _delegate;
}

- (TPTransfersManager*)transfersManager
{
	return _transfersManager;
}

- (TPHostCapability)localHostCapabilities
{
	return _capabilities;
}

- (TPRemoteHost*)connectedHost
{
	return _connectedHost;
}

- (void)setConnectedHost:(TPRemoteHost*)connectedHost
{
	if(connectedHost != _connectedHost) {
		_connectedHost = connectedHost;
	}
	
	NSString * remoteAddress = [_socket remoteAddress];
	if(remoteAddress != nil)
		[_connectedHost setAddress:remoteAddress];
}

- (BOOL)isValidForHost:(TPRemoteHost*)host
{
	if(host == nil || _connectedHost == nil) {
		return NO;
	}
	if(![_connectedHost isEqual:host]) {
		return NO;
	}
	if([self localHostCapabilities] != [[TPLocalHost localHost] capabilities]) {
		return NO;
	}
	if(![[_socket remoteAddress] isEqualToString:[host address]]) {
		return NO;
	}
	return YES;
}


#pragma mark -
#pragma mark Commands

- (void)disconnect
{
	[_socket close];
	[_pendingMessages removeAllObjects];
}

- (BOOL)sendMessage:(TPMessage*)message
{
	if([_socket socketState] == TPSocketConnectedState) {
#if DEBUG_GENERAL
		DebugLog(@"%s %@", __PRETTY_FUNCTION__, message);
#endif
		NSData * rawData = [message rawData];
		BOOL result = [_socket sendData:rawData];
		if(!result) {
			if(_delegate && [_delegate respondsToSelector:@selector(connectionDisconnected:)])
				[_delegate connectionDisconnected:self];
		}
		return result;
	}
	else if([_socket socketState] == TPSocketConnectingState) {
		[_pendingMessages addObject:message];
		return YES;
	}
	else
		return NO;
}

- (BOOL)_sendPendingMessages
{
	BOOL success = YES;
	
	if([_pendingMessages count] > 0) {
		NSEnumerator * messagesEnum = [_pendingMessages objectEnumerator];
		TPMessage * pendingMessage;
		
		while((pendingMessage = [messagesEnum nextObject]) != nil) {
			if(![self sendMessage:pendingMessage]) {
				success = NO;
				DebugLog(@"error sending pending message %@", pendingMessage);
			}
		}
		
		[_pendingMessages removeAllObjects];
	}
	
	return success;
}


#pragma mark -
#pragma mark TCP Socket delegate

- (void)tcpSocket:(TPTCPSocket*)tcpSocket gotData:(NSData*)data
{
#if	DEBUG_GENERAL
	DebugLog(@"%@ got data %@", tcpSocket,  data);
#endif
	
	if([data length] == 0) {
		DebugLog(@"empty data");
		return;
	}
	
	[_msgBuffer appendData:data];
	
	BOOL cont = YES;
	while([_msgBuffer length] >= TPMessageHeaderLength && cont) {
		TPMessage * message = [[TPMessage alloc] initWithRawData:_msgBuffer];
		if(message != nil) {
			TPDataLength msgLength = [message msgLength];
			if(msgLength > 0) {
				[_msgBuffer replaceBytesInRange:NSMakeRange(0, msgLength) withBytes:NULL length:0];
				if([_delegate respondsToSelector:@selector(connection:receivedMessage:)])
					[_delegate connection:self receivedMessage:message];
			}
			else
				cont = NO;
		}
		else
			cont = NO;
	}
	
}

- (void)tcpSocketConnectionClosed:(TPTCPSocket*)tcpSocket
{
	[_msgBuffer setData:[NSData data]];
	
	
	if(_delegate && [_delegate respondsToSelector:@selector(connectionDisconnected:)])
		[_delegate connectionDisconnected:self];
	
	[self disconnect];
	
}

@end
