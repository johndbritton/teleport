//
//  TPEventsTransmitter.m
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003 abyssoft. All rights reserved.
//

#import "TPEventsTransmitter.h"
#import "TPMasterController.h"
#import "TPUDPSocket.h"
#import "TPMessage.h"
#import "common.h"
#include <stdio.h>

@implementation TPEventsTransmitter

- (BOOL)connectToHost:(NSString*)host onPort:(int)port
{
    [super connect];
    udpSocket = [[TPUDPSocket UDPSocketConnectedToHost:host port:port] retain];
    if(!udpSocket)
        return FALSE;
    [udpSocket setDelegate:self];
    return TRUE;
}

@end
