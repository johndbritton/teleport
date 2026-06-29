//
//  TPHotBorder.m
//  Teleport
//
//  Created by JuL on Sun Dec 07 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPHotBorder.h"
#import "TPHotBorderView.h"
#import "TPPreferencesManager.h"


static NSString * TPHotBorderLocationKey = @"TPHotBorderLocation";
static NSString * TPHotBorderDraggingInfoKey = @"TPHotBorderDraggingInfo";

@interface TPHotBorder ()
{
	BOOL _ignoringEvents;
}

- (void)_discardFireAttempt;

@end

@implementation TPHotBorder

+ (TPHotBorder*)hotBorderRepresentingRect:(NSRect)representedRect inRect:(NSRect)parentRect
{
	TPHotBorder * hotBorder = [[TPHotBorder alloc] initWithRepresentingRect:representedRect inRect:parentRect];
	return hotBorder;
}

+ (NSRect)hotRectWithRepresentingRect:(NSRect)representedRect inRect:(NSRect)parentRect
{
	NSRect hotRect;
	NSRect enlargedRect;
	
#if 1
	enlargedRect = NSInsetRect(representedRect, -BORDER_SIZE, -BORDER_SIZE);
	hotRect = NSIntersectionRect(parentRect, enlargedRect);
#else
	enlargedRect = representedRect;
	enlargedRect.origin.x -= BORDER_SIZE;
	enlargedRect.size.width += 2*BORDER_SIZE;
	
	hotRect = NSIntersectionRect(parentRect, enlargedRect);
	
//	DebugLog(@"1representedRect=%@, parentRect=%@, BORDER_SIZE=%d, offSetRect=%@, hotRect=%@", NSStringFromRect(representedRect), NSStringFromRect(parentRect), BORDER_SIZE, NSStringFromRect(NSOffsetRect(representedRect,BORDER_SIZE,BORDER_SIZE)), NSStringFromRect(hotRect));
	
	if(!NSEqualRects(hotRect, NSZeroRect))
		return hotRect;
	
	enlargedRect = representedRect;
	enlargedRect.origin.y -= BORDER_SIZE;
	enlargedRect.size.height += 2*BORDER_SIZE;
	
	hotRect = NSIntersectionRect(parentRect, enlargedRect);
#endif
	
//	DebugLog(@"2representedRect=%@, parentRect=%@, BORDER_SIZE=%d, offSetRect=%@, hotRect=%@", NSStringFromRect(representedRect), NSStringFromRect(parentRect), BORDER_SIZE, NSStringFromRect(NSOffsetRect(representedRect,BORDER_SIZE,BORDER_SIZE)), NSStringFromRect(hotRect));
	
	return hotRect;
}

- (instancetype) initWithRepresentingRect:(NSRect)representedRect inRect:(NSRect)parentRect
{
	self = [super initWithContentRect:representedRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	
	[self setAlphaValue:1.0];
	[self setOpaque:NO];
	[self setHasShadow:NO];
	[self setLevel:kCGDraggingWindowLevel-1];
	
	[self setReleasedWhenClosed:NO];
	[self setDelegate:self];
	
	/* Setup view */
	TPHotBorderView * hotView = [[TPHotBorderView alloc] initWithFrame:NSZeroRect];
	[self setContentView:hotView];
	
	_state = TPHotBorderInactiveState;
	_hotDelegate = nil;
	identifier = nil;
	_fireTimer = nil;
	_trackingRectTag = -1;
	
	[self updateWithRepresentingRect:representedRect inRect:parentRect];
	
	[self orderFront:self];
	
	if([self respondsToSelector:@selector(setCollectionBehavior:)]) {
		[self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorStationary];
	}
	
	return self;
}

- (void)dealloc
{
	[_tapTimer invalidate];
	_tapTimer = nil;
	[self _discardFireAttempt];
}

- (void)updateWithRepresentingRect:(NSRect)representedRect inRect:(NSRect)parentRect
{
	NSRect hotRect = [TPHotBorder hotRectWithRepresentingRect:representedRect inRect:parentRect];
	TPGluedRect(NULL, &_side, parentRect, representedRect, TPUndefSide);

	[self setFrame:hotRect display:YES];
	
	NSView * hotView = [self contentView];
	
	if(_trackingRectTag != -1) {
		[hotView removeTrackingRect:_trackingRectTag];
	}
	
	_trackingRectTag = [hotView addTrackingRect:[hotView bounds] owner:self userData:NULL assumeInside:NO];
}

- (void)activate
{
	if(NSPointInRect([self mouseLocationOutsideOfEventStream], [[self contentView] bounds])) {
		[self performSelector:@selector(activate) withObject:nil afterDelay:0.1]; // post-pone activation until mouse is not already in the hot border
	}
	else {
		_state = TPHotBorderActiveState;
	}
}

- (void)deactivate
{
	_state = TPHotBorderInactiveState;
}

- (TPHotBorderState)state
{
	return _state;
}

- (void)setDoubleTap:(BOOL)doubleTap
{
	_doubleTap = doubleTap;
}

- (BOOL)doubleTap
{
	return _doubleTap;
}

- (void)setAcceptDrags:(BOOL)acceptDrags
{
	_acceptDrags = acceptDrags;
	
	[self setIgnoresMouseEvents:!acceptDrags];
	
	if(acceptDrags) {
		[self setLevel:kCGDraggingWindowLevel-1];
		[[self contentView] registerForDraggedTypes:@[NSFilenamesPboardType]];
	}
	else {
		[self setLevel:kCGMaximumWindowLevel];
		[[self contentView] unregisterDraggedTypes];
	}
}

- (BOOL)acceptDrags
{
	return _acceptDrags;
}

- (void)setDelegate:(id)delegate
{
	_hotDelegate = delegate;
}

- (void)setIdentifier:(NSString*)inIdentifier
{
	identifier = [inIdentifier copy];
}

- (NSString*)identifier
{
	return identifier;
}

- (void)setOpaqueToMouseEvents:(BOOL)opaque
{
	TPHotBorderView * hotView = (TPHotBorderView*)[self contentView];
	
	if(opaque) {
		_ignoringEvents = YES;
		[self setIgnoresMouseEvents:NO];
		[hotView setColor:[NSColor colorWithCalibratedWhite:0.5 alpha:0.2]];
		[hotView display];
	}
	else {
		_ignoringEvents = NO;

		[self setIgnoresMouseEvents:!_acceptDrags];
		[hotView setColor:[hotView normalColor]];
		[hotView display];
	}
}

- (NSRect)hotRect
{
	return [self frame];
}

- (TPSide)side
{
	return _side;
}

- (void)delayedActivate
{
	float inhibitionPeriod = [[TPPreferencesManager sharedPreferencesManager] floatForPref:INHIBITION_PERIOD];
	if(inhibitionPeriod > 0.0) {
		_state = TPHotBorderActivatingState;
		[NSTimer scheduledTimerWithTimeInterval:inhibitionPeriod target:self selector:@selector(activate) userInfo:nil repeats:NO];
	}
	else {
		[self activate];
	}
}

- (NSPoint)screenPointFromLocalPoint:(NSPoint)localPoint flipped:(BOOL)flipped
{
	NSPoint point = [self convertBaseToScreen:localPoint];
	if(flipped) {
		point.y = NSMaxY([[NSScreen screens][0] frame]) - point.y;
	}
	return point;
}

- (void)mouseDown:(NSEvent*)event
{
	DebugLog(@"mouseDown");
	[super mouseDown:event];
}

- (void)mouseUp:(NSEvent*)event
{
	DebugLog(@"mouseUp");
	[super mouseUp:event];
}


#pragma mark -
#pragma mark Fire methods

- (void)_fireAttemptWithEvent:(NSEvent*)event atLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	if(_state != TPHotBorderActiveState) {
		DebugLog(@"not active");
		return;
	}
	if(_hotDelegate == nil) {
		DebugLog(@"nil _hotDelegate!");
		return;
	}
	if (_ignoringEvents) {
		DebugLog(@"ignoring events");
		return;
	}
	if([_hotDelegate respondsToSelector:@selector(hotBorder:canFireWithEvent:)]) {
		if(![_hotDelegate hotBorder:self canFireWithEvent:event]) {
			DebugLog(@"can't activate!");
			return;
		}
	}
	
	if(_doubleTap) {
		if(_tapTimer == nil) {
			float tapInterval = [[TPPreferencesManager sharedPreferencesManager] floatForPref:DOUBLE_TAP_INTERVAL];
			_tapTimer = [NSTimer scheduledTimerWithTimeInterval:tapInterval target:self selector:@selector(tapIntervalExpired:) userInfo:nil repeats:NO];
			return;
		}
		else {
			[_tapTimer invalidate];
			_tapTimer = nil;
		}
	}
	
	float delay = [(id)self.delegate hotBorderSwitchDelay:self];
	if(delay > 0.0) {
		NSMutableDictionary * fireDict = [NSMutableDictionary dictionary];
		
		fireDict[TPHotBorderLocationKey] = [NSValue valueWithPoint:location];
		
		if (draggingInfo != nil) {
			fireDict[TPHotBorderDraggingInfoKey] = draggingInfo;
		}
		
		_fireTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(_fireWithTimer:) userInfo:fireDict repeats:NO];
	}
	else {
		[self fireAtLocation:location withDraggingInfo:draggingInfo];
	}
}

- (void)tapIntervalExpired:(NSTimer*)tapTimer
{
	_tapTimer = nil;
}

- (void)_discardFireAttempt
{
	[_fireTimer invalidate];
	_fireTimer = nil;
}

- (void)mouseEntered:(NSEvent *)event
{
	DebugLog(@"mouseEntered");
	
	[self _discardFireAttempt];
	
	NSUInteger buttonState = [NSEvent pressedMouseButtons];
	
	if(buttonState == 0) { // no mouse button down
		[self _fireAttemptWithEvent:event atLocation:[event locationInWindow] withDraggingInfo:nil];
	}
}

- (void)mouseExited:(NSEvent *)event
{
	DebugLog(@"mouseExited");
	
	[self _discardFireAttempt];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	DebugLog(@"drag entered\ntypes=%@", [[sender draggingPasteboard] types]);
	
	[self _discardFireAttempt];
	
	NSPoint point = [sender draggingLocation];
	[self _fireAttemptWithEvent:[NSApp currentEvent] atLocation:point withDraggingInfo:sender];
	
	return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	DebugLog(@"drag exited");
	
	[self _discardFireAttempt];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	DebugLog(@"prepareForDragOperation");
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	DebugLog(@"performDragOperation");
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	DebugLog(@"concludeDragOperation");
}

- (void)_fireWithTimer:(NSTimer*)timer
{
	NSDictionary * fireDict = [timer userInfo];
	NSPoint location = [fireDict[TPHotBorderLocationKey] pointValue];
	
	[self fireAtLocation:location withDraggingInfo:fireDict[TPHotBorderDraggingInfoKey]];
}
	
- (void)fireAtLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	[self _discardFireAttempt];
	
	if(![_hotDelegate respondsToSelector:@selector(hotBorder:firedAtLocation:withDraggingInfo:)]) {
		DebugLog(@"delegate does not respond to selector!");
		return;
	}
	
	DebugLog(@"Fire %@ at position=%@", self, NSStringFromPoint(location));
	
	[self deactivate];
	
	BOOL doFireAnimation = [_hotDelegate hotBorder:self firedAtLocation:location withDraggingInfo:draggingInfo];

	if(doFireAnimation)
		[(TPHotBorderView*)[self contentView] fireAtLocation:location];
	else
		;
}

@end
