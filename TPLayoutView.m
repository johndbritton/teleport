//
//  TPLayoutView.m
//  teleport
//
//  Created by JuL on Thu Feb 26 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPLayoutView.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"

#import "TPLayoutRemoteHostView.h"
#import "TPLayoutLocalHostView.h"

#import "TPAnimationManager.h"
#import "TPHostAnimationController.h"

#import "TPPreferencePane.h"
#import "TPHostsManager.h"
#import "TPHostSnapping.h"

#define DEFAULT_SCALE 0.1
#define DEFAULT_HEIGHT 100
#define HOST_MARGIN 8
#define LINE_MARGIN 0
#define LINE_THICKNESS 1.0

#define DEBUG_SNAP 0
#define SNAP_DURATION 2.0
#define BOTTOM_MARGIN 20

NSRect TPScaledRect(NSRect rect, float scale)
{
	NSRect scaledRect = rect;
	scaledRect.origin.x *= scale;
	scaledRect.origin.y *= scale;
	scaledRect.size.width *= scale;
	scaledRect.size.height *= scale;
	return scaledRect;
}

@implementation TPLayoutView {
	BOOL animateContent;
}

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if(self) {
		_scaleFactor = DEFAULT_SCALE;
		
		self.wantsLayer = YES;
		self.clipsToBounds = YES;
		animateContent = NO;
		
		_localHostView = [[TPLayoutLocalHostView alloc] initWithHost:[TPLocalHost localHost] layoutView:self];
		[self addSubview:_localHostView];
		_remoteHostsViews = [[NSMutableDictionary alloc] init];
		
//		_layoutHosts = [[NSMutableDictionary alloc] init];
//		_layoutLocalHost = [[TPLayoutLocalHostView alloc] initWithHost:[TPLocalHost localHost] layoutView:self];
//		[self addSubview:_layoutLocalHost];
//		_scrollerDeltaX = 0.0;
//		_scroller = nil;

	}
	return self;
}


- (void)awakeFromNib
{
	[self setWantsLayer:YES];
	CALayer *layer = [CALayer layer];
	self.layer = layer;
	
	CGColorRef backgroundColor = CGColorCreateGenericGray(1.0, 0.5);
	layer.backgroundColor = backgroundColor;
	CFRelease(backgroundColor);
	
	layer.borderWidth = 1.0;
	
	CGColorRef borderColor = CGColorCreateGenericGray(0.5, 1.0);
	layer.borderColor = borderColor;
	layer.cornerRadius = 4.0;
	CFRelease(borderColor);
//	[self performSelector:@selector(setWantsLayer:) withObject:[NSNumber numberWithBool:YES]];
	
	[self updateLayout];
}


#pragma mark -
#pragma mark Updating

- (NSArray*)remoteHosts
{
	return [[TPHostsManager defaultManager] hostsWithState:(TPHostAllStates & ~TPHostUndefState)];
}

- (TPLayoutRemoteHostView*)remoteHostViewForHost:(TPRemoteHost*)host
{
	return _remoteHostsViews[[host identifier]];
}


#pragma mark -
#pragma mark Layouting

- (void)_addSubviewWithFadeIn:(NSView*)subview
{
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.0];
	[subview setAlphaValue:0.0];
	[NSAnimationContext endGrouping];
	[self addSubview:subview];
	[[subview animator] setAlphaValue:1.0];
}

- (void)_updateViews
{
	NSArray * hosts = [[self remoteHosts] hostsWithState:(TPHostSharedState|TPHostIncompatibleState|TPHostPeeredState)];
	NSEnumerator * hostsEnum = [hosts objectEnumerator];
	TPRemoteHost * host;
	
	NSMutableSet * removedHosts = [[NSMutableSet alloc] initWithArray:[_remoteHostsViews allKeys]];
	
	while((host = [hostsEnum nextObject])) {
		NSString * remoteHostIdentifier = [host identifier];
		TPLayoutRemoteHostView * remoteHostView = _remoteHostsViews[remoteHostIdentifier];
		if(remoteHostView == nil) {
			remoteHostView = [[TPLayoutRemoteHostView alloc] initWithHost:host layoutView:self];
			[remoteHostView update];
			_remoteHostsViews[remoteHostIdentifier] = remoteHostView;
			[self _addSubviewWithFadeIn:remoteHostView];
		}
		else {
			[remoteHostView setHostIdentifier:remoteHostIdentifier];
			[removedHosts removeObject:remoteHostIdentifier];
		}
	}
	
	NSEnumerator * removedHostsEnum = [removedHosts objectEnumerator];
	NSString * removedHostKey;
	
	while((removedHostKey = [removedHostsEnum nextObject])) {
		TPLayoutRemoteHostView * remoteHostView = _remoteHostsViews[removedHostKey];
		[remoteHostView removeFromSuperview];
		[_remoteHostsViews removeObjectForKey:removedHostKey];
	}
	
}

- (void)_updateScaleFactor
{
	NSRect bounds = [self bounds];
	
	NSRect localHostRect = [_localHostView totalFrame];
	
	NSSize maxHostSize = NSZeroSize;
	NSSize maxSharedHostSize = NSZeroSize;
	NSEnumerator * hostViewsEnum = [_remoteHostsViews objectEnumerator];
	TPLayoutRemoteHostView * hostView;
	
	while((hostView = [hostViewsEnum nextObject])) {
		TPRemoteHost * host = (TPRemoteHost*)[hostView host];
		NSRect hostRect = [hostView totalFrame];
		maxHostSize.width = MAX(maxHostSize.width, NSWidth(hostRect));
		maxHostSize.height = MAX(maxHostSize.height, NSHeight(hostRect));
		
		if(![host isInState:TPHostPeeredState]) {
			maxSharedHostSize.width = MAX(maxSharedHostSize.width, NSWidth(hostRect));
			maxSharedHostSize.height = MAX(maxSharedHostSize.height, NSHeight(hostRect));
		}
	}
	
	if(!NSEqualSizes(maxHostSize, NSZeroSize)) {
		float scaleFactorV = ((NSHeight(bounds) - BOTTOM_MARGIN) - 4 * HOST_MARGIN - LINE_THICKNESS) / (3 * maxHostSize.height + NSHeight(localHostRect));
		float scaleFactorH = (NSWidth(bounds) - 2 * HOST_MARGIN) / (2 * maxHostSize.width + NSWidth(localHostRect));
		
		_scaleFactor = MIN(MAX(MIN(scaleFactorH, scaleFactorV), MIN_SCALE), MAX_SCALE);
	}
	else {
		_scaleFactor = DEFAULT_SCALE;
	}
	
	//NSLog(@"scaleFactor: %f", _scaleFactor);
	
	if(!NSEqualSizes(maxSharedHostSize, NSZeroSize)) {
		_layoutHeight = round(NSHeight(bounds) - (maxSharedHostSize.height * _scaleFactor + 2 * HOST_MARGIN));
	}
	else {
		_layoutHeight = NSHeight(bounds);
	}
}

- (void)_updateScroller
{
	NSArray * hosts = [[self remoteHosts] hostsWithState:(TPHostSharedState|TPHostIncompatibleState)];
	NSRect fullFrame = [self frame];
	
	if([hosts count] == 0) {
		if(_scroller != nil) {
			[_scroller removeFromSuperview];
			_scroller = nil;
		}
	}
	else {
		/* Calculate width */
		float width = HOST_MARGIN;
		NSEnumerator * hostsEnum = [hosts objectEnumerator];
		TPRemoteHost * host;
		while(host = [hostsEnum nextObject]) {
			NSRect hostRect = [host fullHostRect];
			width += (floor(hostRect.size.width*_scaleFactor) + HOST_MARGIN);
		}
		
		float proportion = NSWidth(fullFrame) / width;
		
		if(proportion < 1.0) {
			NSRect scrollerFrame = NSMakeRect(LINE_THICKNESS, _layoutHeight - [NSScroller scrollerWidth], NSWidth(fullFrame) - 2*LINE_THICKNESS, [NSScroller scrollerWidth]);
			
			if(_scroller == nil) {
				_scroller = [[NSScroller alloc] initWithFrame:scrollerFrame];
				[self addSubview:_scroller];
				[_scroller setTarget:self];
				[_scroller setAction:@selector(scroll:)];
			}
			
			[_scroller setFloatValue:_scrollerDeltaX / (NSWidth(fullFrame) - width) knobProportion:proportion];
			[_scroller setFrame:scrollerFrame];
			[_scroller setEnabled:YES];
			[_scroller setHidden:NO];
		}
		else {
			[_scroller removeFromSuperview];
			_scroller = nil;
		}
	}
}

- (void)_updateLayout
{
	NSRect bounds = [self bounds];
	
	// Local host
	NSRect localHostRect = [_localHostView totalFrame];
	localHostRect = TPScaledRect(localHostRect, _scaleFactor);
		
	NSPoint origin = NSMakePoint(floor((NSWidth(bounds) - NSWidth(localHostRect)) / 2.0),
								 floor((_layoutHeight + BOTTOM_MARGIN - NSHeight(localHostRect)) / 2.0));

	[_localHostView updateLayoutWithScaleFactor:_scaleFactor];
	[_localHostView setFrameOrigin:origin];
	
	NSMutableArray<NSView*> *contentViews = [[NSMutableArray alloc] init];
	[contentViews addObject:_localHostView];
	CGRect contentFrame = _localHostView.frame;

	// Remote hosts
	NSEnumerator * hostViewsEnum = [_remoteHostsViews objectEnumerator];
	TPLayoutRemoteHostView * hostView;
	
	//float hostOrigin = _layoutHeight + HOST_MARGIN;
	NSPoint sharedHostPoint = NSMakePoint(HOST_MARGIN + _scrollerDeltaX, _layoutHeight + HOST_MARGIN);
	
	while((hostView = [hostViewsEnum nextObject])) {
		TPRemoteHost * host = (TPRemoteHost*)[hostView host];
		NSRect totalFrame = [hostView totalFrame];		
		NSRect frame;
		TPSide side = TPUndefSide;
		BOOL isInContentView = NO;
		if([host isInState:TPHostPeeredState]) {
			NSRect localScreenFrame = [_localHostView screenFrameAtIndex:0];
			//NSLog(@"localHostView: %@, localScreenFrame: %@",localHostView,NSStringFromRect(localScreenFrame));
						
			NSRect hostRect = [host hostRect];
			frame = TPScaledRect(hostRect, _scaleFactor);
			frame.origin.x += NSMinX(localScreenFrame);
			frame.origin.y += NSMinY(localScreenFrame);
			
			frame.size.width = floor(NSWidth(frame));
			frame.size.height = floor(NSHeight(frame));

			frame = [hostView hostFrameFromScreenFrame:frame atIndex:[host sharedScreenIndex]];
			
			NSRect representedRect = [host adjustedHostRect];
			NSRect parentRect = [[host localScreen] frame];
			TPGluedRect(NULL, &side, parentRect, representedRect, TPUndefSide);
			
			[contentViews addObject:hostView];
			isInContentView = YES;
		}
		else {
			frame = TPScaledRect(totalFrame, _scaleFactor);
			frame.size.width = floor(NSWidth(frame));
			frame.size.height = floor(NSHeight(frame));
			
			frame.origin = sharedHostPoint;
			sharedHostPoint.x += NSWidth(frame) + HOST_MARGIN;
		}
		
		double (*xFunc)(double) = NULL;
		double (*yFunc)(double) = NULL;
		if(side & TPRightSide) {
			xFunc = floor;
		}
		else if(side & TPLeftSide) {
			xFunc = ceil;
		}
		else {
			xFunc = floor;
		}
		
		if(side & TPTopSide) {
			yFunc = floor;
		}
		else if(side & TPBottomSide) {
			yFunc = ceil;
		}
		else {
			yFunc = floor;
		}
		
		frame.origin.x = xFunc(NSMinX(frame));
		frame.origin.y = yFunc(NSMinY(frame));
		
		[hostView updateLayoutWithScaleFactor:_scaleFactor];
		[hostView setFrameOrigin:frame.origin];
		if (isInContentView) {
			contentFrame = CGRectUnion(contentFrame, hostView.frame);
		}
	}
	
	// Adjust content views
	CGFloat offsetX = floor((NSWidth(bounds) - NSWidth(contentFrame)) / 2.0 - NSMinX(contentFrame));
	CGFloat offsetY = floor((_layoutHeight - NSHeight(contentFrame)) / 2.0 - NSMinY(contentFrame));
	for (NSView *view in contentViews) {
		if (animateContent) {
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
				context.duration = 0.1;
				context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

				[[view animator] setFrame:CGRectOffset(view.frame, offsetX, offsetY)];
			} completionHandler:nil];
		} else {
			[view setFrame:CGRectOffset(view.frame, offsetX, offsetY)];
		}
	}
	animateContent = NO;
	
	[CATransaction begin];
	[CATransaction setValue:@YES forKey:kCATransactionDisableActions];
	
	// Separation line
	NSArray * onlineHosts = [[self remoteHosts] hostsWithState:TPHostSharedState|TPHostIncompatibleState|TPHostPeeringState];
	if(([onlineHosts count] > 0) && (_scroller == nil || [_scroller isHidden])) {
		if(_separationLine == nil) {
			_separationLine = [CALayer layer];
			[[self layer] insertSublayer:_separationLine atIndex:0];
			CGColorRef grayColor = CGColorCreateGenericGray(0.5, 1.0);
			_separationLine.backgroundColor = grayColor;
			CFRelease(grayColor);
		}
		_separationLine.frame = CGRectMake(LINE_MARGIN, _layoutHeight, NSWidth(bounds) - 2 * LINE_MARGIN, LINE_THICKNESS);
	}
	else if(_separationLine != nil) {
		[_separationLine removeFromSuperlayer];
		_separationLine = nil;
	}
	
	NSArray *peeredHosts = [[self remoteHosts] hostsWithState:TPHostPeeredState|TPHostOnlineState];
	if (peeredHosts.count == 0) {
		infoLabel.stringValue = NSLocalizedString(@"No shared Mac found on local network. Please check \\U201CShare this Mac\\U201D on the Macs you want to control.", nil);	}
	else {
		infoLabel.stringValue = NSLocalizedString(@"Arrange the shared Macs around your screen to control them. Configure options on each one.", nil);
	}
	
	[CATransaction commit];
}

- (void)updateLayout
{
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0];
	[self _updateViews];
	[self _updateScaleFactor];
	[self _updateScroller];
	[self _updateLayout];
	[NSAnimationContext endGrouping];
	//[self setNeedsDisplay:YES];

}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
	[self updateLayout];
}


#pragma mark -
#pragma mark Events

- (void)_dragHostView:(TPLayoutRemoteHostView*)hostView withInitialEvent:(NSEvent*)initialEvent
{
	NSPoint point = [initialEvent locationInWindow];
	point = [hostView convertPoint:point fromView:nil];
	unsigned draggingScreenIndex = [hostView indexOfScreenAtPoint:point];

	if(draggingScreenIndex == -1)
		return;
	
	// put the view at the top
	[hostView removeFromSuperview];
	[self addSubview:hostView];
	
	[hostView setDraggingScreenIndex:draggingScreenIndex];
	
	TPRemoteHost * host = (TPRemoteHost*)[hostView host];
	NSEvent * event = initialEvent;
	//NSRect viewFrame = [hostView frame];
	NSRect frame = [hostView screenFrameAtIndex:draggingScreenIndex];
	NSRect snappedFrame;
	BOOL snapped = NO;
	unsigned nearestScreenIndex = 0;
	float minDist;
	NSRect minGluedRect = NSZeroRect;
	TPSide minSide = TPUndefSide;	
	NSPoint hostPosition;

	[hostView mouseExited:initialEvent];
	
	TPHostPlacementIndicator * indicator = [[TPHostPlacementIndicator alloc] initWithHost:host];
	
#if DEBUG_SNAP
	CALayer * debugSnapLayer = [CALayer layer];
	debugSnapLayer.frame = NSRectToCGRect([hostView screenFrameAtIndex:draggingScreenIndex]);
	debugSnapLayer.backgroundColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 0.5);
	debugSnapLayer.zPosition = 10.0;
	[[self layer] addSublayer:debugSnapLayer];
#endif
	
	while(1) {		
		frame.origin.x += [event deltaX];
		frame.origin.y -= [event deltaY];
		
#if DEBUG_SNAP
		[CATransaction begin];
		[CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
		debugSnapLayer.frame = NSRectToCGRect(frame);
		[CATransaction commit];
#endif
		
		snappedFrame = frame;
		
#define ANIMATE_SNAP 0
#define DISTANCE_TO_SNAP 30
#define SQUARED_DISTANCE_TO_SNAP (DISTANCE_TO_SNAP*DISTANCE_TO_SNAP)
		
		
		nearestScreenIndex = [_localHostView nearestScreenIndexForFrame:frame distance:&minDist position:&(minGluedRect.origin) side:&minSide];
		
		
		hostPosition = minGluedRect.origin;
		NSPoint localHostPosition = [_localHostView screenFrameAtIndex:0].origin;
		hostPosition.x = (hostPosition.x - localHostPosition.x)/_scaleFactor;
		hostPosition.y = (hostPosition.y - localHostPosition.y)/_scaleFactor;
		//NSLog(@"hostPosition: %@", NSStringFromPoint(hostPosition));
		hostPosition = [hostView adjustedScreenPositionFromPosition:hostPosition localScreenIndex:nearestScreenIndex side:minSide];
		//NSLog(@"hostPosition2: %@", NSStringFromPoint(hostPosition));
		NSRect hostRect = [host hostRect];
		hostRect.origin = hostPosition;
		
		BOOL animate = NO;
		
		snappedFrame.origin = minGluedRect.origin;
		
		[indicator setHostRect:hostRect localScreenIndex:nearestScreenIndex];
		
		//	DebugLog(@"minDist=%f", minDist);
		if(minDist < SQUARED_DISTANCE_TO_SNAP) {
			if(!snapped) {
				[indicator show];
				animate = ANIMATE_SNAP;
				_snapTime = 0.0;
			}
			snapped = YES;
//			hostPosition.x = (hostPosition.x/_scaleFactor - localHostPosition.x);
//			hostPosition.y = (hostPosition.y/_scaleFactor - localHostPosition.y);
			//[self snapToScreenIndex:nearestScreenIndex atPosition:hostPosition ofSide:minSide];
		}
		else {
			if(snapped) {
				[indicator close];
				//animate = YES;
				_snapTime = 0.0;
			}

			snapped = NO;
			//[self unsnap];
		}
		
		NSTimeInterval duration = 0.0;
		

		
#if ANIMATE_SNAP
		NSTimeInterval timeIntervalSinceReferenceDate = [NSDate timeIntervalSinceReferenceDate];
		
		BOOL hasRunningAnimation = (_snapTime > timeIntervalSinceReferenceDate);
		
		if(animate && !hasRunningAnimation) {
			_snapTime = timeIntervalSinceReferenceDate + SNAP_DURATION;
		}
		
		duration = (_snapTime - timeIntervalSinceReferenceDate);

		
		if(hasRunningAnimation) {
			
			CGFloat percent = (SNAP_DURATION - duration)/SNAP_DURATION;
//			if(!snapped)
//				percent = 1.0 - percent;
			
			NSRect intermediateFrame = frame;
			
			intermediateFrame.origin.x += percent * (NSMinX(snappedFrame) - NSMinX(frame));
			intermediateFrame.origin.y += percent * (NSMinY(snappedFrame) - NSMinY(frame));

			
			
			[NSAnimationContext beginGrouping];
			
			[hostView setFrame:intermediateFrame];
			
			[NSAnimationContext endGrouping];
			
		}
		
		//NSLog(@"duration: %f", duration);

#endif
		
		NSRect hostFrame = snapped ? snappedFrame : frame;
		hostFrame = [hostView hostFrameFromScreenFrame:hostFrame atIndex:draggingScreenIndex];
		
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:duration];

		
		if(duration > 0.0)
			[[hostView animator] setFrame:hostFrame];
		else
			[hostView setFrame:hostFrame];
		
		[NSAnimationContext endGrouping];
		
		event = [NSApp nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
		
		if([event type] == NSLeftMouseUp) {
			break;
		}		
	}
	
#if DEBUG_SNAP
	[debugSnapLayer removeFromSuperlayer];
#endif
	
	[indicator close];
	
	// Always animate paired hosts to center after dragging.
	animateContent = YES;
	if(snapped) {
		//[[TPHostAnimationController controller] showAppearanceAnimationForHost:host];
		[hostView pairToScreenIndex:nearestScreenIndex atPosition:hostPosition ofSide:minSide];
	}
	else if([host isInState:TPHostPeeredState]) {
		[hostView unpair];
	}
	else {
		[self updateLayout];
	}
	
	[hostView setDraggingScreenIndex:-1];

}

- (void)mouseDown:(NSEvent*)event
{
	NSPoint point = [[self superview] convertPoint:[event locationInWindow] fromView:nil];
	NSView * view = [self hitTest:point];

	if([view isKindOfClass:[TPLayoutRemoteScreenView class]]) {
		TPLayoutRemoteHostView * remoteHostView = (TPLayoutRemoteHostView*)[(TPLayoutRemoteScreenView*)view hostView];
		[self _dragHostView:remoteHostView withInitialEvent:event];
	}
}

- (IBAction)scroll:(id)sender
{
	NSRect fullFrame = [self bounds];
	float value = [_scroller floatValue];
	
	_scrollerDeltaX = round(- value*(NSWidth(fullFrame)/[_scroller knobProportion]-NSWidth(fullFrame)));
	
	[self _updateLayout];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	if(_scroller == nil) return;
	
	NSRect fullFrame = [self bounds];
	CGFloat deltaX = - _scrollerDeltaX - [theEvent deltaX];
	
	_scrollerDeltaX = round(- MAX(0.0, MIN((NSWidth(fullFrame)/[_scroller knobProportion]-NSWidth(fullFrame)), deltaX)));
	
	[self _updateScroller];
	[self _updateLayout];
}

//+ (id)defaultAnimationForKey:(NSString *)key
//{
//	return nil;
//}
//
//- (id)animationForKey:(NSString*)key
//{
//	NSLog(@"KEY: %@", key);
//	return [CABasicAnimation animation];
//}



#pragma mark -
#pragma mark Animation

//- (id<CAAction>)actionForKey:(NSString*)key
//{
//	NSLog(@"pouet");
//	return [CABasicAnimation animation];
//}

@end
