//
//  TPUDPSocket.h
//  teleport
//
//  Created by JuL on Sat Jan 03 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <netinet/in.h>

@interface TPUDPSocket : NSObject
{
	id delegate;
	BOOL connected;
	CFSocketRef cfSocket;
}

+ (TPUDPSocket*)udpSocketWithPort:(int)port;
- initWithPort:(int)port;

- (void)setDelegate:(id)delegate;

- (BOOL)sendData:(NSData*)data to:(CFDataRef)address;
- (void)close;

@end

@interface NSObject (TPUDPSocket_delegate)

- (void)udpSocket:(TPUDPSocket*)udpSocket gotData:(NSData*)data from:(CFDataRef)address;

@end
