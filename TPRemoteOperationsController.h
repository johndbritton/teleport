//
//  TPRemoteOperationsController.h
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TPEventsController.h"
#import "TPMessage.h"

#define BUTTON_COUNT 8

@protocol TPEventDelegate <NSObject>

- (BOOL)applicationWillSendEvent:(NSEvent*)event;

@end

@class TPEventCatcherWindow;

@interface TPRemoteOperationsController : TPEventsController <TPEventDelegate>
{
	TPEventCatcherWindow * _eventCatcherWindow;
	NSMutableSet * _modifierStates; // stores modifiers that are currently down
	BOOL _buttonStates[BUTTON_COUNT];
}

@end
