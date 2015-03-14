//
//  TPEventTapsController.m
//  teleport
//
//  Created by JuL on 09/11/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPEventTapsController.h"
#import "TPEventTapsController_Internal.h"

#import "TPPreferencesManager.h"
#import "TPMainController.h"

#include <Carbon/Carbon.h>

#define DEBUG_EVENTTAP 0
#define MAX_STRING 20

void CGSSetConnectionProperty(int, int, CFStringRef, CFBooleanRef);
int _CGSDefaultConnection();

static TPEventTapsController * _eventTapsController = nil;

static const char * eventTypeName[] =
{
	"NullEvent", "LMouseDown", "LMouseUp", "RMouseDown", "RMouseUp",
	"MouseMoved", "LMouseDragged", "RMouseDragged", "MouseEntered",
	"MouseExited", "KeyDown", "KeyUp", "FlagsChanged", "Kitdefined",
	"SysDefined", "AppDefined", "Timer", "CursorUpdate",
	"Journaling", "Suspend", "Resume", "Notification",
	"ScrollWheel", "TabletPointer", "TabletProximity",
	"OtherMouseDown", "OtherMouseUp", "OtherMouseDragged", "Zoom"
};

@interface TPEventTapsController (Internal)

- (void)_startGettingsEvents;
- (void)_postEvent:(CGEventRef)event;

- (BOOL)_shouldSkipFirstEvent:(id)e;
- (BOOL)_isEmergencyStopEvent:(id)e;

@end

@implementation TPEventTapsController

+ (TPEventsController*)defaultController
{
	if(_eventTapsController == nil)
		_eventTapsController = [[TPEventTapsController alloc] init];
	return _eventTapsController;
}

static CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
	TPEventTapsController * self = (__bridge TPEventTapsController*)refcon;
	
#if DEBUG_EVENTTAP
	NSLog(@"Callback: %@", [TPEventTapsController _eventNameFromType:type]);
#endif

	if(type == kCGEventTapDisabledByTimeout) {
		[self _startGettingsEvents];
	}
	else {
		[self _sendEventToListener:(__bridge id)event];
	}
	
	return NULL;
}

+ (NSString*)_eventNameFromType:(CGEventType)type
{
	if(type < (sizeof eventTypeName / sizeof eventTypeName[0])) {
		return @(eventTypeName[type]);
	}
	else {
		return [NSString stringWithFormat:@"Event Type 0x%x", type];
	}
}


#pragma mark -
#pragma mark Getting events

- (void)_startGettingEventsOnScreen:(NSScreen*)screen
{
#if DISABLE_CONTROL
	return;
#endif
	
	if(IsSecureEventInputEnabled()) {
		[(TPMainController*)[NSApp delegate] goFrontmost];
	}
	
	// Hack to make background cursor setting work
	CFStringRef propertyString = CFStringCreateWithCString(NULL, "SetsCursorInBackground", kCFStringEncodingUTF8);
	CGSSetConnectionProperty(_CGSDefaultConnection(), _CGSDefaultConnection(), propertyString, kCFBooleanTrue);
	CFRelease(propertyString);
	
	CGDisplayHideCursor(kCGDirectMainDisplay);
	
	if(_eventPort == NULL) {
		CFRunLoopRef runLoop = CFRunLoopGetCurrent();

		_eventPort = CGEventTapCreate(kCGSessionEventTap,
									  kCGHeadInsertEventTap,
									  0,
#if 0
									  CGEventMaskBit(kCGEventLeftMouseDown)		|
									  CGEventMaskBit(kCGEventLeftMouseUp)		|
									  CGEventMaskBit(kCGEventRightMouseDown)	|
									  CGEventMaskBit(kCGEventRightMouseUp)		|
									  CGEventMaskBit(kCGEventMouseMoved)		|
									  CGEventMaskBit(kCGEventLeftMouseDragged)	|
									  CGEventMaskBit(kCGEventRightMouseDragged)	|
									  CGEventMaskBit(kCGEventKeyDown)			|
									  CGEventMaskBit(kCGEventKeyUp)				|
									  CGEventMaskBit(kCGEventFlagsChanged)		|
									  CGEventMaskBit(kCGEventScrollWheel)		|
									  CGEventMaskBit(kCGEventTabletPointer)		|
									  CGEventMaskBit(kCGEventTabletProximity)	|
									  CGEventMaskBit(kCGEventOtherMouseDown)	|
									  CGEventMaskBit(kCGEventOtherMouseUp)		|
									  CGEventMaskBit(kCGEventOtherMouseDragged)	|
									  CGEventMaskBit(NX_ZOOM),
#else
									  kCGEventMaskForAllEvents & ~(NX_KITDEFINEDMASK |
																   NX_APPDEFINEDMASK),
#endif
									  eventCallback,
									  (__bridge void *)(self));
		if(_eventPort == NULL) {
			NSLog(@"Can't create event port");
			return;
		}
		
		CFRunLoopSourceRef eventSrc = CFMachPortCreateRunLoopSource(NULL, _eventPort, 0);
		if(eventSrc == NULL) {
			NSLog(@"Can't create event src");
		}
		else {
			CFRunLoopAddSource(runLoop, eventSrc, kCFRunLoopDefaultMode);
			CFRelease(eventSrc);
		}
	}
	else {
		[self _startGettingsEvents];
	}
}

- (void)_sendEventToListener:(id)event
{
	if(CGEventTapIsEnabled(_eventPort)) {
		[super _sendEventToListener:event];
	}
}

- (void)_startGettingsEvents
{
	if(_eventPort != NULL) {
		CGEventTapEnable(_eventPort, true);
	}
}

- (void)_stopGettingEvents
{
	if(_eventPort != NULL) {
		CGEventTapEnable(_eventPort, false);
	}
	
	[(TPMainController*)[NSApp delegate] leaveFrontmost];
}

- (void)cleanupGettingEvents
{
	[super cleanupGettingEvents];
		
	CGDisplayShowCursor(kCGDirectMainDisplay);
}


#pragma mark -
#pragma mark Posting events

- (void)startPostingEvents
{
	_eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
	
//	CGEventSourceSetLocalEventsFilterDuringSuppressionState(_eventSource, 0, kCGEventSuppressionStateSuppressionInterval);
	
//	_eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
//	_eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
}

- (void)stopPostingEvents
{
	if(_eventSource != NULL) {
		CFRelease(_eventSource);
		_eventSource = NULL;
	}
}

- (void)_postEvent:(CGEventRef)event
{
	CGEventSetTimestamp(event, CGSCurrentEventTimestamp());
//	CGEventSourceStateID sourceState = CGEventSourceGetSourceStateID(_eventSource);
//	CGEventFlags flags = CGEventSourceFlagsState(sourceState);
//	DebugLog(@"event flags=%lld", CGEventGetFlags(event));
//	DebugLog(@"before source flags=%lld", flags);
//	CGEventSetFlags(event, flags);
//	DebugLog(@"post event %s", eventTypeName[eventType]);
	
	if(_eventSource != NULL) {
		CGEventSetSource(event, _eventSource);
	}
	
	CGEventPost(kCGSessionEventTap, event);
//	DebugLog(@"after source flags=%lld", CGEventSourceFlagsState(sourceState));
}


#pragma mark -
#pragma mark Conversions

#define APPEND_INTEGER(key) \
{ \
    int64_t value = CGEventGetIntegerValueField(event, key); \
    int64_t swappedValue = NSSwapHostLongLongToBig(value); \
    [eventData appendData:[NSData dataWithBytes:&swappedValue length:sizeof(int64_t)]]; \
}

#define APPEND_DOUBLE(key) \
{ \
    double value = CGEventGetDoubleValueField(event, key); \
    NSSwappedDouble swappedValue = NSSwapHostDoubleToBig(value); \
    [eventData appendData:[NSData dataWithBytes:&swappedValue length:sizeof(NSSwappedDouble)]]; \
}

#define READ_INTEGER(key) \
{ \
    int64_t swappedValue; \
    [eventData _readBytes:&swappedValue withSize:sizeof(int64_t) atPos:&pos]; \
    int64_t value = NSSwapBigLongLongToHost(swappedValue); \
    CGEventSetIntegerValueField(event, key, value); \
}

#define READ_DOUBLE(key) \
{ \
    NSSwappedDouble swappedValue; \
    [eventData _readBytes:&swappedValue withSize:sizeof(NSSwappedDouble) atPos:&pos]; \
    double value = NSSwapBigDoubleToHost(swappedValue); \
    CGEventSetDoubleValueField(event, key, value); \
}

- (NSData*)_eventDataFromEvent:(id)e
{
	CGEventRef event = (__bridge CGEventRef)e;
	
	NSMutableData * eventData = [[NSMutableData alloc] init];
	
	CGEventType eventType = CGEventGetType(event);
	CGEventType swappedEventType = NSSwapHostIntToBig(eventType);
	
//	DebugLog(@"postEvent: %d", eventType);
	
	/* Write event type */
	[eventData appendData:[NSData dataWithBytes:&swappedEventType length:sizeof(CGEventType)]];
	
	/* Write event data */
	switch(eventType) {
		case kCGEventMouseMoved:
		case kCGEventLeftMouseDragged:
		case kCGEventRightMouseDragged:
		case kCGEventOtherMouseDragged:
		{
			APPEND_INTEGER(kCGMouseEventNumber)
			APPEND_INTEGER(kCGMouseEventDeltaX)
			APPEND_INTEGER(kCGMouseEventDeltaY)
			APPEND_INTEGER(kCGMouseEventButtonNumber)
			break;
		}
		case kCGEventScrollWheel:
		case NX_ZOOM:
		{
			APPEND_INTEGER(kCGScrollWheelEventDeltaAxis1)
			APPEND_INTEGER(kCGScrollWheelEventDeltaAxis2)
			APPEND_INTEGER(kCGScrollWheelEventDeltaAxis3)

			if(1) {
				APPEND_INTEGER(kCGScrollWheelEventScrollPhase)
				APPEND_INTEGER(kCGScrollWheelEventIsContinuous)
				
				APPEND_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis1)
				APPEND_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis2)
				APPEND_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis3)
				APPEND_DOUBLE(kCGScrollWheelEventPointDeltaAxis1)
				APPEND_DOUBLE(kCGScrollWheelEventPointDeltaAxis2)
				APPEND_DOUBLE(kCGScrollWheelEventPointDeltaAxis3)
			}
			break;
		}
		case kCGEventLeftMouseDown:
		case kCGEventLeftMouseUp:
		case kCGEventRightMouseDown:
		case kCGEventRightMouseUp:
		case kCGEventOtherMouseDown:
		case kCGEventOtherMouseUp:
		{
			APPEND_INTEGER(kCGMouseEventNumber)
			APPEND_INTEGER(kCGMouseEventButtonNumber)
			APPEND_INTEGER(kCGMouseEventClickState)
			APPEND_INTEGER(kCGMouseEventInstantMouser)
			APPEND_INTEGER(kCGMouseEventSubtype)
			APPEND_DOUBLE(kCGMouseEventPressure)
			break;
		}
		case kCGEventKeyUp:
		case kCGEventKeyDown:
		{
			CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
			CGKeyCode swappedKeyCode = NSSwapHostShortToBig(keyCode);
			[eventData appendData:[NSData dataWithBytes:&swappedKeyCode length:sizeof(CGKeyCode)]];
			
			APPEND_INTEGER(kCGKeyboardEventKeyboardType)
			
			UniChar string[MAX_STRING];
			UniCharCount length;
			CGEventKeyboardGetUnicodeString(event, MAX_STRING, &length, string);
			
//			DebugLog(@"OUT string=%@ eventkbt: %d", [NSString stringWithCharacters:string length:length], keyboardType);
			
			UniCharCount swappedLength = NSSwapHostIntToBig(length);
			[eventData appendData:[NSData dataWithBytes:&swappedLength length:sizeof(UniCharCount)]];
			
			UniCharCount i;
			for(i=0; i<length; i++) {
				UniChar c = string[i];
				UniChar swappedC = NSSwapHostShortToBig(c);
				[eventData appendData:[NSData dataWithBytes:&swappedC length:sizeof(UniChar)]];
			}
			break;
		}
		case kCGEventFlagsChanged:
		default:
			break;
	}
	
	CGEventFlags flags = CGEventGetFlags(event);
	CGEventFlags swappedFlags = NSSwapHostLongLongToBig(flags);
//	DebugLog(@"flags=%lld", flags);
	[eventData appendData:[NSData dataWithBytes:&swappedFlags length:sizeof(CGEventFlags)]];

	return eventData;
}

- (void)_postEventWithEventData:(NSData*)eventData
{
	int pos = 0;
	bool down = false;
	
	CGEventRef event = NULL;
	
	int swappedEventType;
	[eventData _readBytes:&swappedEventType withSize:sizeof(int) atPos:&pos];
	CGEventType eventType = NSSwapBigIntToHost(swappedEventType);
	
	switch(eventType) {
		case kCGEventLeftMouseDown:
		case kCGEventLeftMouseUp:
		case kCGEventRightMouseDown:
		case kCGEventRightMouseUp:
		case kCGEventOtherMouseDown:
		case kCGEventOtherMouseUp:
		{
			event = CGEventCreateMouseEvent(_eventSource, eventType, _currentMouseLocation, 0);
			CGEventSetType(event, eventType); // there's a bug on Tiger
			
			READ_INTEGER(kCGMouseEventNumber)
			READ_INTEGER(kCGMouseEventButtonNumber)
			READ_INTEGER(kCGMouseEventClickState)
			READ_INTEGER(kCGMouseEventInstantMouser)
			READ_INTEGER(kCGMouseEventSubtype)
			READ_DOUBLE(kCGMouseEventPressure)
			break;
		}
		case kCGEventMouseMoved:
		case kCGEventLeftMouseDragged:
		case kCGEventRightMouseDragged:
		case kCGEventOtherMouseDragged:
		{			
			event = CGEventCreateMouseEvent(_eventSource, eventType, _currentMouseLocation, 0);
			CGEventSetType(event, eventType); // there's a bug on Tiger
			
			READ_INTEGER(kCGMouseEventNumber)
			READ_INTEGER(kCGMouseEventDeltaX)
			READ_INTEGER(kCGMouseEventDeltaY)
			READ_INTEGER(kCGMouseEventButtonNumber)

			TPMouseDelta mouseDelta;
			mouseDelta.x = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
			mouseDelta.y = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
			
			[self _updateMouseLocationWithMouseDelta:mouseDelta];
			
			CGEventSetLocation(event, _currentMouseLocation);
			break;
		}
		case kCGEventScrollWheel:
		case NX_ZOOM:
		{
			event = CGEventCreate(_eventSource);
			CGEventSetType(event, eventType); // there's a bug on Tiger
			
			READ_INTEGER(kCGScrollWheelEventDeltaAxis1)
			READ_INTEGER(kCGScrollWheelEventDeltaAxis2)
			READ_INTEGER(kCGScrollWheelEventDeltaAxis3)
			
			if(1) {
				READ_INTEGER(kCGScrollWheelEventScrollPhase)
				READ_INTEGER(kCGScrollWheelEventIsContinuous)
				
				READ_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis1)
				READ_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis2)
				READ_DOUBLE(kCGScrollWheelEventFixedPtDeltaAxis3)
				READ_DOUBLE(kCGScrollWheelEventPointDeltaAxis1)
				READ_DOUBLE(kCGScrollWheelEventPointDeltaAxis2)
				READ_DOUBLE(kCGScrollWheelEventPointDeltaAxis3)
			}
			break;
		}
		case kCGEventKeyDown:
			down = true;
		case kCGEventKeyUp:
		{
			CGKeyCode swappedKeyCode, keyCode;
			
			[eventData _readBytes:&swappedKeyCode withSize:sizeof(CGKeyCode) atPos:&pos];
			keyCode = NSSwapBigShortToHost(swappedKeyCode);
			
			event = CGEventCreateKeyboardEvent(_eventSource, keyCode, down);
			CGEventSetType(event, eventType); // there's a bug on Tiger

			READ_INTEGER(kCGKeyboardEventKeyboardType)
			
			UniCharCount swappedLength, length;
			
			[eventData _readBytes:&swappedLength withSize:sizeof(UniCharCount) atPos:&pos];
			length = NSSwapBigIntToHost(swappedLength);
			
			UniChar string[MAX_STRING];
			UniCharCount i;
			for(i=0; i<length; i++) {
				UniChar c, swappedC;
				[eventData _readBytes:&swappedC withSize:sizeof(UniChar) atPos:&pos];
				c = NSSwapBigShortToHost(swappedC);
				string[i] = c;
			}
			
//			DebugLog(@"IN string=%@ eventkbt: %d sourcekbt: %d", [NSString stringWithCharacters:string length:length], keyboardType, CGEventSourceGetKeyboardType(_eventSource));
//			CGEventKeyboardSetUnicodeString(event, length, string);
//
//			if(CGEventSourceGetKeyboardType(_eventSource) != keyboardType)
//				CGEventSourceSetKeyboardType(_eventSource, keyboardType);
			break;
		}
		case kCGEventFlagsChanged:
		{
			event = CGEventCreate(_eventSource);
			CGEventSetType(event, eventType); // there's a bug on Tiger
			break;
		}
		default:
			break;
	}
	
	if(event != NULL) {
		CGEventFlags swappedFlags, flags;

		[eventData _readBytes:&swappedFlags withSize:sizeof(CGEventFlags) atPos:&pos];
		flags = NSSwapBigLongLongToHost(swappedFlags);
		
		CGEventSetFlags(event, flags);
		
		[self _postEvent:event];
		CFRelease(event);
	}
}


#pragma mark -
#pragma mark Misc

- (BOOL)_shouldSkipFirstEvent:(id)e
{
	CGEventRef event = (__bridge CGEventRef)e;
	switch(CGEventGetType(event)) {
		case kCGEventMouseMoved:
		case kCGEventLeftMouseDragged:
		case kCGEventRightMouseDragged:
		case kCGEventOtherMouseDragged:
			return YES;
		default:
			return NO;
	}
}

- (NSEvent*)_nsEventFromEvent:(id)event
{
	return [NSEvent eventWithCGEvent:(CGEventRef)event];
}

- (BOOL)_isEmergencyStopEvent:(id)e
{
	CGEventRef event = (__bridge CGEventRef)e;
	if(CGEventGetType(event) != kCGEventKeyDown)
		return NO;
	CGEventFlags flags = CGEventGetFlags(event);
	if((flags & kCGEventFlagMaskShift) == 0)
		return NO;
	if((flags & kCGEventFlagMaskControl) == 0)
		return NO;
	if((flags & kCGEventFlagMaskAlternate) == 0)
		return NO;
	CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
	if(keyCode != ESC_KEYCODE)
		return NO;
	
	return YES;
}

- (void)warpMouseToPosition:(NSPoint)position
{
	[super warpMouseToPosition:position];
	
	DebugLog(@"warp to %@", NSStringFromPoint(position));
	
	CGEventSourceStateID sourceState;
	
	if(_eventSource != NULL) {
		sourceState = CGEventSourceGetSourceStateID(_eventSource);
	}
	else {
		sourceState = kCGEventSourceStateCombinedSessionState;
	}
	
	CGEventRef event = NULL;
	
	if(CGEventSourceButtonState(sourceState, kCGMouseButtonLeft)) {
		event = CGEventCreateMouseEvent(_eventSource, kCGEventLeftMouseDragged, *(CGPoint*)&position, kCGMouseButtonLeft);
		CGEventSetType(event, kCGEventLeftMouseDragged); // there's a bug on Tiger
	}
	else if(CGEventSourceButtonState(sourceState, kCGMouseButtonRight)) {
		event = CGEventCreateMouseEvent(_eventSource, kCGEventRightMouseDragged, *(CGPoint*)&position, kCGMouseButtonRight);
		CGEventSetType(event, kCGEventRightMouseDragged); // there's a bug on Tiger
	}
	else if(CGEventSourceButtonState(sourceState, kCGMouseButtonCenter)) {
		event = CGEventCreateMouseEvent(_eventSource, kCGEventOtherMouseDragged, *(CGPoint*)&position, kCGMouseButtonCenter);
		CGEventSetType(event, kCGEventOtherMouseDragged); // there's a bug on Tiger
	}
	else {
		event = CGEventCreateMouseEvent(_eventSource, kCGEventMouseMoved, *(CGPoint*)&position, 0);
		CGEventSetType(event, kCGEventMouseMoved); // there's a bug on Tiger
	}
	
	if(event != NULL) {
		[self _postEvent:event];
		CFRelease(event);
	}
}
	
- (void)mouseDownAtPosition:(NSPoint)position
{
	[super mouseDownAtPosition:position];

	CGEventRef event = CGEventCreateMouseEvent(_eventSource, kCGEventLeftMouseDown, _currentMouseLocation, kCGMouseButtonLeft);
	CGEventSetType(event, kCGEventLeftMouseDown); // there's a bug on Tiger
	if(event != NULL) {
		[self _postEvent:event];
		CFRelease(event);
	}
}

- (void)mouseUpAtPosition:(NSPoint)position
{
	[super mouseUpAtPosition:position];
	
	CGEventRef event = CGEventCreateMouseEvent(_eventSource, kCGEventLeftMouseUp, _currentMouseLocation, kCGMouseButtonLeft);
	CGEventSetType(event, kCGEventLeftMouseUp); // there's a bug on Tiger
	if(event != NULL) {
		CGEventPost(kCGSessionEventTap, event);
		CFRelease(event);
	}
}

- (BOOL)event:(NSEvent*)event hasRequiredKeyIfNeeded:(BOOL)needed withTag:(NSEventType)tag
{
	if(_eventSource == NULL)
		return [super event:event hasRequiredKeyIfNeeded:needed withTag:tag];
	else {
		if(!needed)
			return YES;
		else {
			CGEventSourceStateID sourceState = CGEventSourceGetSourceStateID(_eventSource);
			CGEventFlags flags = CGEventSourceFlagsState(sourceState);
			unsigned int keyMask = NSEventMaskFromType(tag);
			return ((flags & keyMask) != 0);
		}
	}
}

@end
