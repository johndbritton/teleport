//
//  TPUDPSocket.m
//  teleport
//
//  Created by JuL on Sat Jan 03 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPUDPSocket.h"

#import <fcntl.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>

static void _cfsocketCallback(CFSocketRef inCFSocketRef, CFSocketCallBackType inType, CFDataRef inAddress, const void* inData, void* inContext);

@interface TPUDPSocket (Private)

- (void)_receivedData:(CFDataRef)data from:(CFDataRef)inAddress;

@end

@implementation TPUDPSocket

+ (TPUDPSocket*)udpSocketWithPort:(int)port
{
	TPUDPSocket * udpSocket = [[TPUDPSocket alloc] initWithPort:port];
	return [udpSocket autorelease];
}

- initWithPort:(int)port
{
	self = [super init];
	
	/* Setup context */
	CFSocketContext socketContext;
	bzero(&socketContext, sizeof(socketContext));
	socketContext.info = self;
	
	/* Setup struct sockaddr */
	struct sockaddr_in address;
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons(port);
	
	/* Create socket */
	CFDataRef d = CFDataCreate(NULL, (UInt8 *)&address, sizeof(struct sockaddr_in));
	CFSocketSignature signature = {PF_INET, SOCK_DGRAM, IPPROTO_UDP, d};
	cfSocket = CFSocketCreateWithSocketSignature(kCFAllocatorDefault,
												 &signature,
												 kCFSocketDataCallBack,
												 &_cfsocketCallback,
												 &socketContext);
	
	/* Add to the run loop */
	CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, cfSocket, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
	
	return self;
}

- (void)setDelegate:(id)pDelegate
{
	delegate = pDelegate;
}

- (BOOL)sendData:(NSData*)data to:(CFDataRef)address
{
	return (CFSocketSendData(cfSocket, [host cfAddress], (CFDataRef)data, -1) == kCFSocketSuccess);
}

- (void)close
{
	CFSocketInvalidate(cfSocket);
	CFRelease(cfSocket);
}

- (void)_receivedData:(CFDataRef)data from:(CFDataRef)inAddress
{
	if([delegate respondsToSelector:@selector(udpSocket:gotData:from:)])
		[delegate udpSocket:self gotData:(NSData*)data from:inAddress];
}

- (NSString*)remoteAddress
{
	CFSocketNativeHandle nativeSocket;
	struct sockaddr_in address;
	int addressLength = sizeof(address);
	
	nativeSocket = CFSocketGetNative(cfSocket);
	if(nativeSocket < 0)
		return nil;
	
	if(getpeername(nativeSocket, (struct sockaddr*)&address, &addressLength) < 0)
		return nil;
	
	char * cIp = inet_ntoa(address.sin_addr);
	return [NSString stringWithCString:cIp];
}


@end

void 
_cfsocketCallback( CFSocketRef inCFSocketRef, CFSocketCallBackType inType, CFDataRef inAddress, const void* inData, void* inContext )
{
	TPUDPSocket * udpSocket;
	
	udpSocket = (TPUDPSocket*)inContext;
	if(!udpSocket)
		return;
	
	switch(inType)
	{
		case kCFSocketDataCallBack:
			[udpSocket _receivedData:(CFDataRef)inData from:inAddress];
			break;
			
		default:
			break;
	}
}
