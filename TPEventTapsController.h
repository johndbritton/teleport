//
//  TPEventTapsController.h
//  teleport
//
//  Created by JuL on 09/11/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPEventsController.h"

@interface TPEventTapsController : TPEventsController
{
	CFMachPortRef _eventPort;
	CGEventSourceRef _eventSource;
}

@end
