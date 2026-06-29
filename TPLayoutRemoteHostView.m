//
//  TPLayoutRemoteHost.m
//  PrefsPanel
//
//  Created by JuL on Mon Dec 08 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPLayoutRemoteHostView.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"
#import "TPBezierPath.h"
#import "TPPreferencesManager.h"
#import "TPOptionsController.h"
#import "TPLayoutLocalHostView.h"
#import "TPAuthenticationManager.h"

#import "PTKeyComboPanel.h"
#import "PTKeyCombo.h"
#import "PTHotKey.h"

#define TEXT_MARGIN 6

@interface TPOptionsButtonCell : NSButtonCell
@end

@implementation TPOptionsButtonCell

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 1.0, 3.0) xRadius:6.0 yRadius:6.0] fill];
	
	[super drawBezelWithFrame:frame inView:controlView];
}

@end


static NSImage * _lockImage = nil;
static NSImage * _unpairImage = nil;

@interface TPLayoutRemoteHostView (Internal)

- (void)hostDidUpdate:(NSNotification*)notification;

@end

@implementation TPLayoutRemoteScreenView

- (instancetype) initWithHostView:(TPLayoutHostView*)hostView screenIndex:(unsigned)screenIndex
{
	self = [super initWithHostView:hostView screenIndex:screenIndex];
	
	[self _setupButtons];
	
	return self;
}

#pragma mark -
#pragma mark Actions

- (void)_setupButtons
{
	_optionsButton = [[NSButton alloc] initWithFrame:NSZeroRect];
	TPOptionsButtonCell * cell = [[TPOptionsButtonCell alloc] initTextCell:@""];
	[_optionsButton setCell:cell];
	[cell setControlSize:NSMiniControlSize];
	[_optionsButton setBezelStyle:NSRecessedBezelStyle];
	[_optionsButton setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
	[_optionsButton setTitle:NSLocalizedString(@"Options..", @"Title of options button")];
	[_optionsButton setTarget:self];
	[_optionsButton setAction:@selector(showOptionsPanel:)];
	[_optionsButton sizeToFit];
	[_optionsButton setHidden:YES];
	
	NSRect bounds = [self bounds];
	NSRect frame = [_optionsButton frame];
	frame.origin = NSMakePoint(floor((NSWidth(bounds) - NSWidth(frame))/2.0), 4.0);
	[_optionsButton setFrame:frame];
	[_optionsButton setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMaxYMargin];
	
	[self addSubview:_optionsButton];
	
	_trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil];
	[self addTrackingArea:_trackingArea];
	
	_unpairButton = [[NSButton alloc] initWithFrame:NSZeroRect];
	[_unpairButton setBordered:NO];
	[_unpairButton setBezelStyle:NSRegularSquareBezelStyle];
	[_unpairButton setButtonType:NSMomentaryChangeButton];
	//[[_unpairButton cell] setControlSize:NSMiniControlSize];
	[_unpairButton setImage:_unpairImage];
	[_unpairButton setTarget:_hostView];
	[_unpairButton setAction:@selector(unpair)];
	[_unpairButton sizeToFit];
	[_unpairButton setHidden:YES];
	
	frame = [_unpairButton frame];
	frame.origin = NSMakePoint(NSMinX(bounds) + 4.0, NSMaxY(bounds) - NSHeight(frame) - 4.0);
	[_unpairButton setFrame:frame];
	[_unpairButton setAutoresizingMask:NSViewMaxXMargin|NSViewMinYMargin];
	
	[self addSubview:_unpairButton];
}


- (void)_updateUnpairButton
{
	if([(TPLayoutRemoteHostView*)_hostView canUnpair] && [self isSharedScreen])
		[_unpairButton setHidden:NO];
	else
		[_unpairButton setHidden:YES];
}

- (void)_updateOptionsButton
{
	if([self _canShowOptionsButton]) {
		NSPoint location = [NSEvent mouseLocation];
		location = [[self window] convertScreenToBase:location];
		location = [self convertPoint:location fromView:nil];
		
		if(NSPointInRect(location, [self bounds])) {
			[[_optionsButton animator] setHidden:NO];
		}
	}
	else {
		[[_optionsButton animator] setHidden:YES];
	}
}

- (void)update
{
	BOOL drawDimmed = NO;
	unsigned draggingScreenIndex = [(TPLayoutRemoteHostView*)_hostView draggingScreenIndex];
	if(draggingScreenIndex == -1) {
		drawDimmed = [(TPRemoteHost*)[_hostView host] isInState:TPHostPeeredState] && ![self isSharedScreen];
	}
	else {
		drawDimmed = (draggingScreenIndex != [self screenIndex]);
	}
	
	if(drawDimmed) {
		[self setAlphaValue:0.25];
	}
	else {
		[self setAlphaValue:1.0];
	}
	
	[self _updateUnpairButton];
	[self _updateOptionsButton];
	[self setNeedsDisplay:YES];
}

- (BOOL)isSharedScreen
{
	return ([(TPRemoteHost*)[_hostView host] sharedScreenIndex] == [self screenIndex]);
}

- (BOOL)isDraggingScreen
{
	return ([(TPLayoutRemoteHostView*)_hostView draggingScreenIndex] == [self screenIndex]);
}

- (void)mouseEntered:(NSEvent*)event
{
	[self _updateOptionsButton];
}

- (void)mouseExited:(NSEvent*)event
{
	[[_optionsButton animator] setHidden:YES];
}

- (BOOL)_canShowOptionsButton
{
	if(![self isSharedScreen]) {
		return NO;
	}
	
	TPRemoteHost * host = (TPRemoteHost*)[_hostView host];
	return [host isInState:TPHostPeeredOfflineState|TPHostPeeredOnlineState];
}

- (void)showOptionsPanel:(id)sender
{
	[self mouseExited:nil];
	
	NSRect frame = [sender bounds];
	frame = [sender convertRect:frame toView:nil];
	frame.origin = [[sender window] convertBaseToScreen:frame.origin];
	
	[[TPOptionsController controller] showOptionsForHost:(TPRemoteHost*)[_hostView host] sharedScreenIndex:[self screenIndex] fromRect:frame];
}


#pragma mark -
#pragma mark Drawing

- (BOOL)drawDecorations
{
	TPRemoteHost * host = (TPRemoteHost*)[_hostView host];
	BOOL isDragging = ([(TPLayoutRemoteHostView*)_hostView draggingScreenIndex] != -1);
	BOOL drawDecorations;
	
	if(isDragging) {
		drawDecorations = [self isDraggingScreen];
	}
	else if([host isInState:TPHostPeeredState]) {
		drawDecorations = [self isSharedScreen];
	}
	else {
		drawDecorations = [self isMainScreen];
	}
	
	return drawDecorations;
}

- (void)drawRect:(NSRect)rect
{
	TPRemoteHost * host = (TPRemoteHost*)[_hostView host];
	TPHostState hostState = [host hostState];
	NSRect drawRect = [self bounds];
	NSRect titleRect = NSInsetRect(drawRect, 2.0, 2.0);
	BOOL drawDecorations = [self drawDecorations];
	
	if(_cachedBackgroundImage == nil) {
		NSData * data = [host backgroundImageData];
		if(data != nil) {
			_cachedBackgroundHash = [data hash];
			_cachedBackgroundImage = [[NSImage alloc] initWithData:data];
		}
	}
	else {
		unsigned hash = [[host backgroundImageData] hash];
		if(hash != _cachedBackgroundHash) {
			_cachedBackgroundImage = nil;
			[self drawRect:rect];
			return;
		}
	}
	
	float widthInset = 0.0;
	
	switch(hostState) {
		case TPHostPeeredOfflineState:
		{
			[NSBezierPath drawRect:drawRect withGradientFrom:[NSColor blackColor] to:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]];
			break;
		}
		case TPHostControlledState:
		case TPHostPeeredOnlineState:
		case TPHostSharedState:
		case TPHostPeeringState:
		{
			[_cachedBackgroundImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			
			if(drawDecorations && hostState == TPHostControlledState) {
				NSImage * cursorImage = [[NSCursor arrowCursor] image];
				NSRect cursorRect = NSZeroRect;
				cursorRect.size = [cursorImage size];
				
				NSRect mouseRect = cursorRect;
				mouseRect.origin = drawRect.origin;
				mouseRect.origin.x += (drawRect.size.width - cursorRect.size.width)/2;
				mouseRect.origin.y += (drawRect.size.height - cursorRect.size.height)/2;
				
				[cursorImage drawInRect:mouseRect fromRect:cursorRect operation:NSCompositeSourceOver fraction:1.0];
			}
			
			if(drawDecorations && [[TPPreferencesManager sharedPreferencesManager] boolForPref:ENABLED_ENCRYPTION]) {
				if([host hasCapability:TPHostEncryptionCapability]) {
					NSPoint lockPoint = NSMakePoint(NSMaxX(drawRect) - 15.0, NSMaxY(drawRect) - 15.0);
					[_lockImage drawAtPoint:lockPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
					widthInset = 14.0;
				}
			}
			break;
		}
		case TPHostIncompatibleState:
		{
			[NSBezierPath drawRect:drawRect withGradientFrom:[NSColor colorWithCalibratedRed:0.15 green:0.0 blue:0.0 alpha:1.0] to:[NSColor colorWithCalibratedRed:0.35 green:0.0 blue:0.0 alpha:1.0]];
			break;
		}
		default:
			break;
	}
	
	//	if([self canUnpair]) {
	//		NSRect unpairRect = [self unpairRectFromDrawRect:drawRect];
	//		[_unpairImage compositeToPoint:unpairRect.origin operation:NSCompositeSourceOver fraction:_insideButton?1.0:0.75];
	//		widthInset = 14.0;
	//	}
	
	if(widthInset > 0.0) {
		titleRect = NSInsetRect(titleRect, widthInset, 0.0);
	}
	
	if(drawDecorations) {
		[self drawHostTitleInRect:titleRect dimmed:(hostState == TPHostPeeredOfflineState || hostState == TPHostIncompatibleState)];
	}
	
	[[NSColor colorWithCalibratedWhite:0.2 alpha:1.0] set];
	NSFrameRect(drawRect);
}

@end

@implementation TPLayoutRemoteHostView

+ (void)initialize
{
	if(self == [TPLayoutRemoteHostView class]) {
		NSString * imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"Lock_White"];
		_lockImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
		
		imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"remove.tiff"];
		_unpairImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
	}
}

+ (Class)screenViewClass
{
	return [TPLayoutRemoteScreenView class];
}

- (instancetype) initWithHost:(TPHost*)host layoutView:(TPLayoutView*)layoutView
{
	_draggingScreenIndex = -1;

	self = [super initWithHost:host layoutView:layoutView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidUpdate:) name:TPHostDidUpdateNotification object:host];
	
	[self setToolTip:[host computerName]];
	
	//[[self screenViews]  _setupButtons];
//	[self setToolTip:[host address]];
	
	return self;
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}


- (void)setDraggingScreenIndex:(unsigned)draggingScreenIndex
{
	_draggingScreenIndex = draggingScreenIndex;
	[self hostDidUpdate:nil];
}

- (unsigned)draggingScreenIndex
{
	return _draggingScreenIndex;
}


#pragma mark -
#pragma mark Pairing

- (NSPoint)adjustedScreenPositionFromPosition:(NSPoint)position localScreenIndex:(unsigned)screenIndex side:(TPSide)side
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	NSRect localScreenFrame = [[[TPLocalHost localHost] screenAtIndex:screenIndex] frame];
	
	NSPoint snappedPosition = NSZeroPoint;
	
	NSRect hostRect = [host hostRect];
	
	if((side & TPRightSide) != 0) {
		snappedPosition.x = NSMaxX(localScreenFrame);
		snappedPosition.y = round(position.y);
	}
	if((side & TPLeftSide) != 0) {
		snappedPosition.x = NSMinX(localScreenFrame) - NSWidth(hostRect);
		snappedPosition.y = round(position.y);
	}
	if((side & TPBottomSide) != 0) {
		if(snappedPosition.x == 0.0)
			snappedPosition.x = round(position.x);
		snappedPosition.y = NSMinY(localScreenFrame) - NSHeight(hostRect);
	}
	if((side & TPTopSide) != 0) {
		if(snappedPosition.x == 0.0)
			snappedPosition.x = round(position.x);
		snappedPosition.y = NSMaxY(localScreenFrame);
	}		
	
	snappedPosition.x = MAX(MIN(snappedPosition.x, NSMaxX(localScreenFrame)), NSMinX(localScreenFrame) - NSWidth(hostRect));
	snappedPosition.y = MAX(MIN(snappedPosition.y, NSMaxY(localScreenFrame)), NSMinY(localScreenFrame) - NSHeight(hostRect));
	
	return snappedPosition;
}

- (void)pairToScreenIndex:(int)screenIndex atPosition:(NSPoint)position ofSide:(TPSide)side
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];

	[host setSharedScreenIndex:_draggingScreenIndex];
	[host setLocalScreenIndex:screenIndex];

	NSPoint snappedPosition = [self adjustedScreenPositionFromPosition:position localScreenIndex:screenIndex side:side];
	
	[host setHostPosition:snappedPosition];
	
	DebugLog(@"pairing %@ to screen index %d with shared screen index %d position %@", host, screenIndex, _draggingScreenIndex, NSStringFromPoint(snappedPosition));
	
	if([host isInState:TPHostSharedState]) {
		if([[TPAuthenticationManager defaultManager] requestAuthenticationOnHost:host]) {
			[host setHostState:TPHostPeeringState];
		} else {
			DebugLog(@"Request auth on host %@ failed immediately.", host);
		}
	}
}

- (void)unpair
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	
	DebugLog(@"unpairing host %@", host);
	
	if([host isInState:TPHostOnlineState]) {
		[host setHostState:TPHostSharedState];
	}
	else {
		[host setHostState:TPHostUndefState];
	}
}

- (BOOL)canUnpair
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	return [host isInState:TPHostPeeredOfflineState|TPHostPeeredOnlineState];
}

- (void)update
{
	NSEnumerator * screenViewsEnum = [[self screenViews] objectEnumerator];
	TPLayoutScreenView * localScreenView;
	
	while((localScreenView = [screenViewsEnum nextObject]) != nil) {
		[localScreenView update];
	}	
}

- (void)hostDidUpdate:(NSNotification*)notification
{
	[self update];
}

#if 0


- initWithHost:(TPHost*)host layoutView:(TPLayoutView*)layoutView
{
	self = [super initWithHost:host layoutView:layoutView];
	
	_remoteHostIdentifier = [[(TPRemoteHost*)host identifier] copy];
	_cachedBackgroundImage = nil;
	
	return self;
}

- (void)dealloc
{
	[_remoteHostIdentifier release];
	[_cachedBackgroundImage release];
	[super dealloc];
}

- (NSRect)rectWithSnapping:(BOOL)snapping side:(TPSide*)side
{
	NSRect rect = NSZeroRect;
	TPRemoteHost * host = (TPRemoteHost*)[self host];

	rect.size = [host screenSize];
	
	if([self isSnapped] && snapping) {
		rect.origin = [self snappedPosition];
		NSScreen * screen = [host screenAtIndex:[self snappedScreenIndex]];
		
		if(side != NULL) {
			TPGluedRect(NULL, side, [screen frame], rect);
		}
	}
	
	rect.origin.x += _origin.x;
	rect.origin.y += _origin.y;

	return rect;
}

- (NSRect)drawRectWithSnapping:(BOOL)snapping
{
	NSRect drawRect;
	TPSide side = TPUndefSide;
	NSRect rect = [self rectWithSnapping:snapping side:&side];

	drawRect.origin.x = FORDRAW_ORIGIN(rect.origin.x*scaleFactor);
	drawRect.origin.y = FORDRAW_ORIGIN(rect.origin.y*scaleFactor);
	drawRect.size.height = FORDRAW_SIZE(rect.size.height*scaleFactor);
	drawRect.size.width = FORDRAW_SIZE(rect.size.width*scaleFactor);
	
	// Align on borders
	if(side != TPUndefSide) {
		NSRect localScreenDrawRect = [[_layoutView layoutLocalHost] drawRectForScreen:[(TPRemoteHost*)[self host] screenAtIndex:[self snappedScreenIndex]]];
		if((side & TPRightSide) != 0)
			drawRect.origin.x = NSMaxX(localScreenDrawRect) - 1.0;
		else if((side & TPLeftSide) != 0)
			drawRect.origin.x = NSMinX(localScreenDrawRect) - NSWidth(drawRect) + 1.0;
		if((side & TPTopSide) != 0)
			drawRect.origin.y = NSMaxY(localScreenDrawRect) - 1.0;
		else if((side & TPBottomSide) != 0)
			drawRect.origin.y = NSMinY(localScreenDrawRect) - NSHeight(drawRect) + 1.0;
	}
	
	return drawRect;
}

- (NSRect)unpairRectFromDrawRect:(NSRect)drawRect
{
	return NSMakeRect(NSMinX(drawRect) + 2.0, NSMaxY(drawRect) - 14.0, 12.0, 12.0);
}

- (void)moveToPoint:(NSPoint)point
{
	_origin.x = point.x/scaleFactor + _deltaDrag.x;
	_origin.y = point.y/scaleFactor + _deltaDrag.y;
	
	//DebugLog(@"new pos:%d", layout.position);
}

- (NSPoint)snappedPosition
{
	if(_snapped) {
		return _snappedPosition;
	}
	else {
		return [(TPRemoteHost*)[self host] adjustedHostRect].origin;
	}
}

- (unsigned)snappedScreenIndex
{
	if(_snapped) {
		return _snappedScreenIndex;
	}
	else {
		return [(TPRemoteHost*)[self host] localScreenIndex];
	}
}



#pragma mark -
#pragma mark Events

- (void)mouseDown:(NSEvent*)event
{
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];

	if(![(TPRemoteHost*)[self host] isInState:TPHostDraggableState]) {
		NSBeep();
	}
	else {
		_dragging = YES;
		
		TPRemoteHost * host = (TPRemoteHost*)[self host];
		_snapped = [host isInState:TPHostPeeredState];
		if(_snapped) {
			_snappedPosition = [host adjustedHostRect].origin;
			_snappedScreenIndex = [host localScreenIndex];
		}
		
		NSPoint origin = [self rectWithSnapping:YES side:NULL].origin;
		_deltaDrag.x = origin.x - dragPoint.x/scaleFactor;
		_deltaDrag.y = origin.y - dragPoint.y/scaleFactor;
		
		
		NSEvent * event = nil;
		while(1) {
			event = [NSApp nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
			point = [self convertPoint:[event locationInWindow] fromView:nil];
			
			if([event type] == NSLeftMouseDragged) {
				NSPoint localPoint = [self convertPoint:point fromView:nil];
				
				[self moveToPoint:localPoint];
				
				NSRect remoteRect = [self drawRectWithSnapping:NO];
				
				unsigned screenIndex = 0; 
				TPLocalHost * localHost = (TPLocalHost*)[_layoutLocalHost host];
				NSScreen * screen;
				float minDist = INFINITY;
				unsigned nearestScreenIndex = 0;
				NSRect minGluedRect = NSZeroRect;
				TPSide minSide = TPLeftSide;
				
				while(screen = [localHost screenAtIndex:screenIndex++]) {
					NSRect localRect = [_layoutLocalHost drawRectForScreen:screen];
					
					NSRect gluedRect;
					TPSide side;
					float dist = TPGluedRect(&gluedRect, &side, localRect, remoteRect);
					if(dist < minDist) {
						minDist = dist;
						nearestScreenIndex = screenIndex-1;
						minGluedRect = gluedRect;
						minSide = side;
					}
				}
				
				//	DebugLog(@"minDist=%f", minDist);
				if(minDist < SQUARED_DISTANCE_TO_SNAP) {
					NSPoint hostPosition = minGluedRect.origin;
					hostPosition.x = (hostPosition.x/_scaleFactor - localHostPosition.x);
					hostPosition.y = (hostPosition.y/_scaleFactor - localHostPosition.y);
					[self snapToScreenIndex:nearestScreenIndex atPosition:hostPosition ofSide:minSide];
				}
				else {
					[self unsnap];
				}
				
				[self setFrame:[self drawRectWithSnapping:NO]];
			}
			else {
				break;
			}
			
			[self display];
		}
		
		
//		if(_scroller != nil)
//			[_scroller setHidden:YES];
	}
}


- (BOOL)handleMouseDownAtPoint:(NSPoint)point
{
	if([self canUnpair]) {
		NSRect drawRect = [self drawRectWithSnapping:YES];
		NSRect unpairRect = [self unpairRectFromDrawRect:drawRect];
		if(NSPointInRect(point, unpairRect)) {
			_insideButton = YES;
			return YES;
		}
	}
	
	return NO;
}

- (void)handleMouseDraggedAtPoint:(NSPoint)point
{
	if([self canUnpair]) {
		NSRect drawRect = [self drawRectWithSnapping:YES];
		NSRect unpairRect = [self unpairRectFromDrawRect:drawRect];
		_insideButton = NSPointInRect(point, unpairRect);
	}
}

- (void)handleMouseUpAtPoint:(NSPoint)point
{
	if([self canUnpair]) {
		NSRect drawRect = [self drawRectWithSnapping:YES];
		NSRect unpairRect = [self unpairRectFromDrawRect:drawRect];
		if(NSPointInRect(point, unpairRect)) {
			[self unpair];
		}
	}
	
	_insideButton = NO;
}

- (void)startDraggingAtPoint:(NSPoint)dragPoint
{
	_dragging = YES;
	
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	_snapped = [host isInState:TPHostPeeredState];
	if(_snapped) {
		_snappedPosition = [host adjustedHostRect].origin;
		_snappedScreenIndex = [host localScreenIndex];
	}
	
	NSPoint origin = [self rectWithSnapping:YES side:NULL].origin;
	_deltaDrag.x = origin.x - dragPoint.x/scaleFactor;
	_deltaDrag.y = origin.y - dragPoint.y/scaleFactor;
}

- (void)stopDragging
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	
	if([self isSnapped]) {
		[host setHostPosition:_snappedPosition];
		[host setLocalScreenIndex:_snappedScreenIndex];
		
		if([host isInState:TPHostSharedState]) {
			[self pair];
		}
	}
	else {
		if([host isInState:TPHostPeeredState]) {
			[self unpair];
		}
	}
	
	_dragging = NO;
	_snapped = NO;
}

- (BOOL)isDragging
{
	return _dragging;
}


#pragma mark -
#pragma mark Snapping

- (void)snapToScreenIndex:(int)screenIndex atPosition:(NSPoint)position ofSide:(TPSide)side
{
	TPRemoteHost * host = (TPRemoteHost*)[self host];
	NSRect localScreenFrame = [[host screenAtIndex:screenIndex] frame];
	
	_snappedScreenIndex = screenIndex;
	_snappedPosition = NSZeroPoint;
	
	NSRect hostRect = [host adjustedHostRect];
	
	if((side & TPRightSide) != 0) {
		_snappedPosition.x = NSMaxX(localScreenFrame);
		_snappedPosition.y = round(position.y);
	}
	if((side & TPLeftSide) != 0) {
		_snappedPosition.x = localScreenFrame.origin.x - hostRect.size.width;
		_snappedPosition.y = round(position.y);
	}
	if((side & TPBottomSide) != 0) {
		if(_snappedPosition.x == 0.0)
			_snappedPosition.x = round(position.x);
		_snappedPosition.y = localScreenFrame.origin.y - hostRect.size.height;
	}
	if((side & TPTopSide) != 0) {
		if(_snappedPosition.x == 0.0)
			_snappedPosition.x = round(position.x);
		_snappedPosition.y = NSMaxY(localScreenFrame);
	}		
	
	_snappedPosition.x = MAX(MIN(_snappedPosition.x, NSMaxX(localScreenFrame)), NSMinX(localScreenFrame) - NSWidth(hostRect));
	_snappedPosition.y = MAX(MIN(_snappedPosition.y, NSMaxY(localScreenFrame)), NSMinY(localScreenFrame) - NSHeight(hostRect));

	DebugLog(@"side=%d position=%@, _snappedPosition=%@, localScreenFrame=%@", side, NSStringFromPoint(position), NSStringFromPoint(_snappedPosition), NSStringFromRect(localScreenFrame));
	
	_snapped = YES;
}

- (void)unsnap
{
	_snapped = NO;
}

- (BOOL)isSnapped
{
	return (_dragging && _snapped) || (!_dragging &&  [(TPRemoteHost*)[self host] isInState:TPHostPeeredState]);
}

- (TPHost*)host
{
	return [[TPHostsManager defaultManager] hostWithIdentifier:_remoteHostIdentifier];
}

- (BOOL)isPointInside:(NSPoint)point
{
	return NSPointInRect(point, [self drawRectWithSnapping:YES]);
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
	if([_layoutView isActive] && [(TPRemoteHost*)[self host] isInState:TPHostPeeredState]) {
		NSMenu * menu = [[NSMenu alloc] init];
		NSMenuItem * deletePeeringMenuItem = [menu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Delete pairing", nil, [NSBundle bundleForClass:[self class]], nil) action:@selector(unpair) keyEquivalent:@""];
		[deletePeeringMenuItem setTarget:self];
		
		return [menu autorelease];
	}
	else {
		return [super menuForEvent:event];
	}
}
#endif
@end
