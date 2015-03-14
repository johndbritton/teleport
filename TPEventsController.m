//
//  TPEventsController.m
//  teleport
//
//  Created by JuL on 09/11/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPEventsController.h"

#import "TPRemoteOperationsController.h"
#import "TPDirectEventTapsController.h"
#import "TPEventTapsController.h"
#import "TPPreferencesManager.h"

#import "TPRemoteHost.h"
#import "TPLocalHost.h"

#define THREADED_EVENT_POSTING 0

@implementation TPEventsController

+ (TPEventsController*)defaultController
{
	if([[TPLocalHost localHost] hasCapability:TPHostEventTapsCapability])
		return [TPEventTapsController defaultController];
	else
		return [TPRemoteOperationsController defaultController];
}

+ (TPEventsController*)eventsControllerForRemoteHost:(TPRemoteHost*)remoteHost
{
	if([[TPLocalHost localHost] pairWithHost:remoteHost hasCapability:TPHostDirectEventTapsCapability]) {
		SInt32 localMajorVersion = [[TPLocalHost localHost] osVersion] & 0xFFF0;
		SInt32 remoteMajorVersion = [remoteHost osVersion] & 0xFFF0;
		// only allow direct event taps between same major OS versions
		if(localMajorVersion == remoteMajorVersion) {
			DebugLog(@"Using TPDirectEventTapsController");
			return [TPDirectEventTapsController defaultController];
		}
		else {
			DebugLog(@"Using TPEventTapsController");
			return [TPEventTapsController defaultController];
		}
	}
	else if([[TPLocalHost localHost] pairWithHost:remoteHost hasCapability:TPHostEventTapsCapability]) {
		DebugLog(@"Using TPEventTapsController");
		return [TPEventTapsController defaultController];
	}
	else {
		DebugLog(@"Using TPRemoteOperationsController");
		return [TPRemoteOperationsController defaultController];
	}
}

- (void)startGettingEventsForListener:(id<TPEventsListener>)eventsListener onScreen:(NSScreen*)screen
{
	_lastPostedEventDate = 0.0;
	_eventsListener = eventsListener;
	
	[self _startGettingEventsOnScreen:screen];
}

- (void)_sendEventToListener:(id)event
{
	id<TPEventsListener> eventsListener = [self eventsListener];
	
	if((_lastPostedEventDate == 0.0) && [self _shouldSkipFirstEvent:event]) {
		DebugLog(@"skipping first event");
	}
	else if(eventsListener != nil) {
		if([self _isEmergencyStopEvent:event]) {
			NSLog(@"emergency stop key sequence detected, disconnecting.");
			[eventsListener gotEmergencyStopEvent];
		}
		else {
			NSEvent * nsEvent = [self _nsEventFromEvent:event];
			if(![eventsListener shouldStopWithEvent:nsEvent]) {
				NSData * eventData = [self _eventDataFromEvent:event];
				[eventsListener gotEventWithEventData:eventData];
			}
		}
	}
	
	_lastPostedEventDate = [NSDate timeIntervalSinceReferenceDate];
}

- (void)stopGettingEvents
{
	[self _stopGettingEvents];
	_eventsListener = nil;
}

- (void)cleanupGettingEvents
{

}

- (id<TPEventsListener>)eventsListener
{
	return _eventsListener;
}

- (void)_startGettingEventsOnScreen:(NSScreen*)screen
{
	// overloaded
}

- (void)_stopGettingEvents
{
	// overloaded
}

- (void)startPostingEvents
{
	_lastPostedEventDate = 0.0;
}

- (void)stopPostingEvents
{
	
}

- (void)_threadedPostEventWithEventData:(NSData*)eventData
{
	@autoreleasepool {
		[self _postEventWithEventData:eventData];
	}
}

- (void)postEventWithEventData:(NSData*)eventData
{
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		
	if (now - _lastPostedEventDate > 60.0) { // if last event occurred more than a minute ago
		[[TPLocalHost localHost] wakeUpScreen];
	}
	
	_lastPostedEventDate = now;
	
#if THREADED_EVENT_POSTING
	[NSThread detachNewThreadSelector:@selector(_threadedPostEventWithEventData:) toTarget:self withObject:eventData];
#else
	[self _postEventWithEventData:eventData];
#endif
}

- (void)_postEventWithEventData:(NSData*)eventData
{
	// overloaded
}

- (void)warpMouseToPosition:(NSPoint)position
{
	_currentMouseLocation = *(CGPoint*)&position;
}

- (void)mouseDownAtPosition:(NSPoint)position
{
	_currentMouseLocation = *(CGPoint*)&position;
}

- (void)mouseUpAtPosition:(NSPoint)position
{
	_currentMouseLocation = *(CGPoint*)&position;
}

- (BOOL)_shouldSkipFirstEvent:(id)event
{
	return NO;
}

- (BOOL)_isEmergencyStopEvent:(id)event
{
	return NO;
}

- (NSEvent*)_nsEventFromEvent:(id)event
{
	return (NSEvent*)event;
}

- (NSData*)_eventDataFromEvent:(id)event
{
	return nil;
}

- (void)_updateMouseLocationWithMouseDelta:(TPMouseDelta)mouseDelta
{
	NSArray * screens = [[TPLocalHost localHost] screens];
	NSRect mainScreenRect = [screens[0] frame];
	
	_currentMouseLocation = [NSEvent mouseLocation];
	_currentMouseLocation.x += mouseDelta.x;
	_currentMouseLocation.y = (NSHeight(mainScreenRect) - _currentMouseLocation.y);
	_currentMouseLocation.y += mouseDelta.y;
	
	NSEnumerator * screenEnum = [screens objectEnumerator];
	NSScreen * screen;
	unsigned i = 0;
	
	while((screen = [screenEnum nextObject])) {
		NSRect screenFrame = [screen frame];
		//	DebugLog(@"point=(%d,%d), screenFrame=%@", point.x, point.y, NSStringFromRect(screenFrame));
		CGPoint relativePoint = _currentMouseLocation;
		relativePoint.x -= NSMinX(screenFrame);
		relativePoint.y -= (NSHeight(mainScreenRect) - NSMaxY(screenFrame));
		
		if(relativePoint.x >= 0 && relativePoint.y >= 0 && relativePoint.x < NSWidth(screenFrame) && relativePoint.y < NSHeight(screenFrame)) {
			_currentScreenIndex = i;
			return;
		}
		i++;
	}
	
	/* Mouse cursor is outside */
	screen = screens[_currentScreenIndex];
	NSRect screenFrame = [screen frame];
	CGPoint relativePoint = _currentMouseLocation;
	relativePoint.x -= NSMinX(screenFrame);
	relativePoint.y -= (NSHeight(mainScreenRect) - NSMaxY(screenFrame));
	
	relativePoint.x = MAX(0, MIN(relativePoint.x, NSWidth(screenFrame) - 1.0));
	relativePoint.y = MAX(0, MIN(relativePoint.y, NSHeight(screenFrame) - 1.0));
	
	_currentMouseLocation = relativePoint;
	_currentMouseLocation.x += NSMinX(screenFrame);
	_currentMouseLocation.y += (NSHeight(mainScreenRect) - NSMaxY(screenFrame));
}

- (BOOL)event:(NSEvent*)event hasRequiredKeyIfNeeded:(BOOL)needed withTag:(NSEventType)tag
{
	if(!needed)
		return YES;
	
	unsigned int keyMask = NSEventMaskFromType(tag);
	DebugLog(@"keyMask: %d modifiersFlags: %d", keyMask, (int)[event modifierFlags]);
	if(([event modifierFlags] & keyMask) != 0)
		return YES;
	
	NSEventModifierFlags flags = [NSEvent modifierFlags];
	DebugLog(@"flags: %lu", flags);
	switch(tag) {
		case COMMAND_KEY_TAG:
			if((flags & NSCommandKeyMask) != 0)
				return YES;
			break;
		case ALT_KEY_TAG:
			if((flags & NSAlternateKeyMask) != 0)
				return YES;
			break;
		case CTRL_KEY_TAG:
			if((flags & NSControlKeyMask) != 0)
				return YES;
			break;
		case SHIFT_KEY_TAG:
			if((flags & NSShiftKeyMask) != 0)
				return YES;
			break;
		case CAPSLOCK_KEY_TAG:
			if((flags & NSAlphaShiftKeyMask) != 0)
				return YES;
			break;
		default:
			break;
		
	}

	return NO;
}

@end
