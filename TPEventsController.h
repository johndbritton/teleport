//
//  TPEventsController.h
//  teleport
//
//  Created by JuL on 09/11/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define ESC_KEYCODE 53
#define DISABLE_CONTROL 0

@class TPRemoteHost;

@protocol TPEventsListener <NSObject>

- (void)gotEventWithEventData:(NSData*)eventData;
- (void)gotEmergencyStopEvent;
- (BOOL)shouldStopWithEvent:(NSEvent*)event;

@end

@interface TPEventsController : NSObject
{
	id<TPEventsListener> _eventsListener;
	
	int _currentScreenIndex;
	CGPoint _currentMouseLocation;
	
	NSTimeInterval _lastPostedEventDate;
}

+ (TPEventsController*)defaultController;
+ (TPEventsController*)eventsControllerForRemoteHost:(TPRemoteHost*)remoteHost;

- (void)startGettingEventsForListener:(id<TPEventsListener>)eventsListener onScreen:(NSScreen*)screen;
- (void)stopGettingEvents;
- (void)cleanupGettingEvents;
@property (nonatomic, readonly, strong) id<TPEventsListener> eventsListener;

- (void)startPostingEvents;
- (void)stopPostingEvents;
- (void)postEventWithEventData:(NSData*)eventData;

- (void)warpMouseToCenter;
- (void)warpMouseToPosition:(NSPoint)position;
- (void)mouseDownAtPosition:(NSPoint)position;
- (void)mouseUpAtPosition:(NSPoint)position;

- (BOOL)event:(NSEvent*)event hasRequiredKeyIfNeeded:(BOOL)needed withTag:(NSEventType)tag;

@end

@interface TPEventsController (Internal)

- (void)_startGettingEventsOnScreen:(NSScreen*)screen;
- (void)_sendEventToListener:(id)event;
- (void)_stopGettingEvents;

- (BOOL)_shouldSkipFirstEvent:(id)event;
- (BOOL)_isEmergencyStopEvent:(id)event;
- (NSEvent*)_nsEventFromEvent:(id)event;
- (NSData*)_eventDataFromEvent:(id)event;
- (void)_postEventWithEventData:(NSData*)eventData;

- (void)_updateMouseLocationWithMouseDelta:(TPMouseDelta)mouseDelta;

@end
