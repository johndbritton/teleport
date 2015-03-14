//
//  TPEventsReceiver.m
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003 abyssoft. All rights reserved.
//

#import "TPEventsReceiver.h"
#import "TPUDPSocket.h"
#import "TPEventsPlayer.h"
#import "common.h"

@implementation TPEventsReceiver

- init
{
    self = [super init];
    //udpSocket = nil;
    return self;
}

- (BOOL)listenOnPort:(int)port
{
    udpSocket = [TPUDPSocket UDPSocketListeningOnPort:port];
    if(!udpSocket)
        return FALSE;
    [udpSocket retain];
    [udpSocket setDelegate:self];
    [self connect];
    //NSLog(@"listening");
    return TRUE;
}

- (void)stopListening
{
    [super disconnect];
}

- (void)disconnect
{
    //[self sendMessage:[TPMessage messageWithType:STOP_CONTROLLING]];
    [self stopListening];
    [super disconnect];
}

@end
