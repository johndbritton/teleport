//
//  TPEventsReceiver.h
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPNetworkConnection.h"

@class TPUDPSocket, TPEventsPlayer;

@interface TPEventsReceiver : TPCommunicationHandler
{
    //TPUDPSocket * listenSocket;
    TPEventsPlayer * eventsPlayer;
}

- init;

- (BOOL)listenOnPort:(int)port;
- (void)stopListening;

- (void)disconnect;

@end
