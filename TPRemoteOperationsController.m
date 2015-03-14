//
//  TPRemoteOperationsController.mm
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPRemoteOperationsController.h"
#import "TPMainController.h"
#import "TPUtils.h"

typedef int CGSConnection;
typedef NS_ENUM(NSInteger, CGSGlobalHotKeyOperatingMode) {
	CGSGlobalHotKeyEnable = 0,
	CGSGlobalHotKeyDisable = 1,
} ;
extern CGSConnection _CGSDefaultConnection(void);
extern CGError CGSSetGlobalHotKeyOperatingMode(CGSConnection connection, CGSGlobalHotKeyOperatingMode mode);

static TPRemoteOperationsController * _remoteOperationsController = nil;


@interface TPEventCatcherWindow : NSWindow
{
	id<TPEventDelegate> _eventsDelegate;
}

- (void)setEventDelegate:(id<TPEventDelegate>)eventDelegate;

@end


@implementation TPEventCatcherWindow

#if LEGACY_BUILD
- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
#else
- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
#endif
{
	self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[self setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.01]];
	[self setAlphaValue:1.0];
	[self setOpaque:NO];
	[self setHasShadow:NO];
	[self setLevel:kCGCursorWindowLevel-1];
	[self setIgnoresMouseEvents:NO];
	[self setAcceptsMouseMovedEvents:YES];
	[self setReleasedWhenClosed:YES];
	
	return self;
}

- (void)setEventDelegate:(id<TPEventDelegate>)eventDelegate
{
	_eventsDelegate = eventDelegate;
}

- (void)sendEvent:(NSEvent *)event
{
	BOOL sendToSuper = YES;
	
	DebugLog(@"sendEvent: %@ (%d)", event, (int)[event type]);
	
	if(_eventsDelegate != nil && [_eventsDelegate respondsToSelector:@selector(applicationWillSendEvent:)]) {
		if(![_eventsDelegate applicationWillSendEvent:event])
			sendToSuper = NO;
	}
	
	if(sendToSuper)
		[super sendEvent:event];
}

@end

@interface TPRemoteOperationsController (Internal)

/* Getting events */
- (void)_sendEventToListener:(NSEvent*)event;
- (NSData*)_eventDataFromEvent:(NSEvent*)event;
- (TPKey)_getKeyFromEvent:(NSEvent*)event;

/* Posting events */
- (NSPoint)_mousePositionFromCurrentPosition:(NSPoint)currentMousePosition andMouseDelta:(TPMouseDelta)mouseDelta;

@end

@implementation TPRemoteOperationsController

+ (TPEventsController*)defaultController
{
	if(_remoteOperationsController == nil)
		_remoteOperationsController = [[TPRemoteOperationsController alloc] init];
	return _remoteOperationsController;
}

- (instancetype) init
{
	self = [super init];

	_modifierStates = [[NSMutableSet alloc] init];
	
	return self;
}



#pragma mark -
#pragma mark Getting events

- (void)_sendModifierEventWithKeyCode:(unsigned short)keyCode
{
	NSEvent * modifierEvent = [NSEvent keyEventWithType:NSFlagsChanged location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL characters:NULL charactersIgnoringModifiers:NULL isARepeat:NO keyCode:keyCode];
	[self _sendEventToListener:modifierEvent];
}

- (void)_startGettingEventsOnScreen:(NSScreen*)screen
{
	[(TPMainController*)[NSApp delegate] goFrontmost];
	
	CGDisplayHideCursor(CGMainDisplayID());
	
	NSRect frame = [screen frame];
	NSPoint centerPoint = NSMakePoint(NSMidX(frame), NSMidY(frame));
	[self warpMouseToPosition:centerPoint];
	
	CGAssociateMouseAndMouseCursorPosition(FALSE);
	
	CGSConnection conn = _CGSDefaultConnection();
	CGSSetGlobalHotKeyOperatingMode(conn, CGSGlobalHotKeyDisable);
	
	_eventCatcherWindow = [[TPEventCatcherWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[_eventCatcherWindow setEventDelegate:self];
	[_eventCatcherWindow makeKeyAndOrderFront:self];
	[NSApp setEventDelegate:self];

	/* Send events for currently down modifiers */
	NSEventModifierFlags modifiers = [NSEvent modifierFlags];
	if((modifiers & NSCommandKeyMask) != 0)
		[self _sendModifierEventWithKeyCode:55];
	if((modifiers & NSShiftKeyMask) != 0)
		[self _sendModifierEventWithKeyCode:56];
	if((modifiers & NSAlphaShiftKeyMask) != 0)
		[self _sendModifierEventWithKeyCode:57];
	if((modifiers & NSAlternateKeyMask) != 0)
		[self _sendModifierEventWithKeyCode:58];
	if((modifiers & NSControlKeyMask) != 0)
		[self _sendModifierEventWithKeyCode:59];
}

- (void)_stopGettingEvents
{
	[NSApp setEventDelegate:nil];
	[_eventCatcherWindow close];
	_eventCatcherWindow = nil;
	
	[_modifierStates removeAllObjects];
	
	CGSConnection conn = _CGSDefaultConnection();
	CGSSetGlobalHotKeyOperatingMode(conn, CGSGlobalHotKeyEnable);
	
	[(TPMainController*)[NSApp delegate] leaveFrontmost];
	
	CGAssociateMouseAndMouseCursorPosition(TRUE);
}

- (void)cleanupGettingEvents
{
	CGDisplayShowCursor(CGMainDisplayID());
}

- (BOOL)applicationWillSendEvent:(NSEvent*)event
{
	switch([event type]) {
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSRightMouseDown:
		case NSRightMouseUp:
		case NSOtherMouseDown:
		case NSOtherMouseUp:
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSOtherMouseDragged:
		case NSFlagsChanged:
		case NSScrollWheel:
		case NSKeyUp:
		case NSKeyDown:
			[self _sendEventToListener:event];
			return NO;
		case NSSystemDefined:
		case NSMouseEntered:
		case NSMouseExited:
		case NSAppKitDefined:
		case NSApplicationDefined:
		case NSPeriodic:
		case NSCursorUpdate:
		default:
			return YES;
	}
}

- (BOOL)_shouldSkipFirstEvent:(id)e
{
	NSEvent * event = (NSEvent*)e;
	switch([event type]) {
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSOtherMouseDragged:
			return YES;
		default:
			return NO;
	}
}

- (BOOL)_isEmergencyStopEvent:(id)e
{
	NSEvent * event = (NSEvent*)e;
	
	if([event type] != NSKeyDown)
		return NO;
	if([event keyCode] != ESC_KEYCODE)
		return NO;
	if(([event modifierFlags] & NSShiftKeyMask) == 0)
		return NO;
	if(([event modifierFlags] & NSControlKeyMask) == 0)
		return NO;
	if(([event modifierFlags] & NSAlternateKeyMask) == 0)
		return NO;
	return YES;
}

- (NSData*)_eventDataFromEvent:(NSEvent*)event
{
	NSMutableData * eventData = [[NSMutableData alloc] init];
	
	NSEventType eventType = [event type];
	int swappedEventType = NSSwapHostIntToBig(eventType);
	
	DebugLog(@"eventDataFromEventType: %d", (int)eventType);
	
	/* Write event type */
	[eventData appendData:[NSData dataWithBytes:&swappedEventType length:sizeof(int)]];
	
	/* Write event data */
	switch(eventType) {
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSRightMouseDown:
		case NSRightMouseUp:
		case NSOtherMouseDown:
		case NSOtherMouseUp:
		{
			int buttonNumber = [event buttonNumber];
			int swappedButtonNumber = NSSwapHostIntToBig(buttonNumber);
			[eventData appendData:[NSData dataWithBytes:&swappedButtonNumber length:sizeof(int)]];
			break;
		}
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSOtherMouseDragged:
		case NSScrollWheel:
		{
			int64_t deltaX = llroundf([event deltaX]);
			int64_t deltaY = llroundf([event deltaY]);
			int64_t swappedDeltaX = NSSwapHostLongLongToBig(deltaX);
			int64_t swappedDeltaY = NSSwapHostLongLongToBig(deltaY);
			[eventData appendData:[NSData dataWithBytes:&swappedDeltaX length:sizeof(int64_t)]];
			[eventData appendData:[NSData dataWithBytes:&swappedDeltaY length:sizeof(int64_t)]];
			break;
		}
		case NSKeyUp:
		case NSKeyDown:
		case NSFlagsChanged:
		{
			TPKey key = [self _getKeyFromEvent:event];
			short short1 = NSSwapHostShortToBig(key.charCode);
			short short2 = NSSwapHostShortToBig(key.keyCode);
			[eventData appendData:[NSData dataWithBytes:&short1 length:sizeof(short)]];
			[eventData appendData:[NSData dataWithBytes:&short2 length:sizeof(short)]];
			break;
		}
		default:
			break;
	}
	
	return eventData;
}

- (TPKey)_getKeyFromEvent:(NSEvent*)event
{
	TPKey key;
	key.keyCode = [event keyCode];
	key.charCode = 0;
	
	if([event type] == NSKeyDown || [event type] == NSKeyUp) {
		NSString * characters = [event charactersIgnoringModifiers];
		
		if(characters != nil && [characters length] > 0)
			key.charCode = [characters characterAtIndex:0];
	}
	
	return key;
}


#pragma mark -
#pragma mark Posting events

- (void)startPostingEvents
{
	[_modifierStates removeAllObjects];
}

- (void)stopPostingEvents
{
	NSEnumerator * modifiersEnum = [_modifierStates objectEnumerator];
	NSNumber * modifierNum;
	while((modifierNum = [modifiersEnum nextObject]) != nil)
		CGPostKeyboardEvent(0, [modifierNum unsignedShortValue], NO);
	
	[_modifierStates removeAllObjects];
}

- (TPKey)_keyFromEventData:(NSData*)eventData pos:(int*)pos
{
	short swappedShort1;
	short swappedShort2;
	
	[eventData _readBytes:&swappedShort1 withSize:sizeof(short) atPos:pos];
	[eventData _readBytes:&swappedShort2 withSize:sizeof(short) atPos:pos];
	
	TPKey key;
	key.charCode = NSSwapBigShortToHost(swappedShort1);
	key.keyCode = NSSwapBigShortToHost(swappedShort2);
	
	return key;
}

- (void)_postMouseEvent
{
	CGPostMouseEvent(_currentMouseLocation, TRUE, BUTTON_COUNT, _buttonStates[0], _buttonStates[1], _buttonStates[2], _buttonStates[3], _buttonStates[4], _buttonStates[5], _buttonStates[6], _buttonStates[7]);
}

- (void)_postEventWithEventData:(NSData*)eventData
{
	int pos = 0;
	
	int swappedEventType;
	[eventData _readBytes:&swappedEventType withSize:sizeof(int) atPos:&pos];
	NSEventType eventType = NSSwapBigIntToHost(swappedEventType);

	switch(eventType) {
		case NSLeftMouseDown:
		case NSRightMouseDown:
		case NSOtherMouseDown:
		{
			int swappedButtonNumber, buttonNumber;
			[eventData _readBytes:&swappedButtonNumber withSize:sizeof(int) atPos:&pos];
			buttonNumber = MIN(NSSwapBigIntToHost(swappedButtonNumber), BUTTON_COUNT-1);
			_buttonStates[buttonNumber] = TRUE;
			[self _postMouseEvent];
			break;
		}
		case NSLeftMouseUp:
		case NSRightMouseUp:
		case NSOtherMouseUp:
		{
			int swappedButtonNumber, buttonNumber;
			[eventData _readBytes:&swappedButtonNumber withSize:sizeof(int) atPos:&pos];
			buttonNumber = MIN(NSSwapBigIntToHost(swappedButtonNumber), BUTTON_COUNT-1);
			_buttonStates[buttonNumber] = FALSE;
			[self _postMouseEvent];
			break;
		}
		case NSMouseMoved:
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSOtherMouseDragged:
		{
			int64_t swappedDeltaX, swappedDeltaY;
			
			[eventData _readBytes:&swappedDeltaX withSize:sizeof(int64_t) atPos:&pos];
			[eventData _readBytes:&swappedDeltaY withSize:sizeof(int64_t) atPos:&pos];
			
			TPMouseDelta mouseDelta;
			mouseDelta.x = NSSwapBigLongLongToHost(swappedDeltaX);
			mouseDelta.y = NSSwapBigLongLongToHost(swappedDeltaY);
			
			[self _updateMouseLocationWithMouseDelta:mouseDelta];
			[self _postMouseEvent];
			break;
		}
		case NSFlagsChanged:
		{
			TPKey key = [self _keyFromEventData:eventData pos:&pos];
			NSNumber * keyNum = @(key.keyCode);
			
			if([_modifierStates containsObject:keyNum]) {
				[_modifierStates removeObject:keyNum];
				CGPostKeyboardEvent(0, key.keyCode, NO);
			}
			else {
				[_modifierStates addObject:keyNum];
				CGPostKeyboardEvent(0, key.keyCode, YES);
			}
			break;
		}
		case NSScrollWheel:
		{
			int swappedDeltaX;
			int swappedDeltaY;
			
			[eventData _readBytes:&swappedDeltaX withSize:sizeof(int) atPos:&pos];
			[eventData _readBytes:&swappedDeltaY withSize:sizeof(int) atPos:&pos];
			
			int deltaX = NSSwapBigIntToHost(swappedDeltaX);
			int deltaY = NSSwapBigIntToHost(swappedDeltaY);

			CGPostScrollWheelEvent(2, deltaY, deltaX);
			break;
		}
		case NSKeyDown:
		{
			TPKey key = [self _keyFromEventData:eventData pos:&pos];
			CGPostKeyboardEvent(key.charCode, key.keyCode, YES);
			break;
		}
		case NSKeyUp:
		{
			TPKey key = [self _keyFromEventData:eventData pos:&pos];
			CGPostKeyboardEvent(key.charCode, key.keyCode, NO);
			break;
		}
		default:
			break;
	}
}

- (void)warpMouseToPosition:(NSPoint)position
{
	[super warpMouseToPosition:position];
	
	CGWarpMouseCursorPosition(_currentMouseLocation);
}
	
- (void)mouseDownAtPosition:(NSPoint)position
{
	[super mouseDownAtPosition:position];
	
	_buttonStates[0] = TRUE;
	[self _postMouseEvent];
}

- (void)mouseUpAtPosition:(NSPoint)position
{
	[super mouseUpAtPosition:position];
	
	_buttonStates[0] = FALSE;
	[self _postMouseEvent];
}

@end
