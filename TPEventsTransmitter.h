//
//  TPEventsTransmitter.h
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPCommunicationHandler.h"

@interface TPEventsTransmitter : TPCommunicationHandler
{
}

- (BOOL)connectToHost:(NSString*)host onPort:(int)port;

@end
