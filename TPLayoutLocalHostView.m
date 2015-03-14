//
//  TPLayoutLocalHost.m
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPLayoutLocalHostView.h"
#import "TPLocalHost.h"
#import "TPPreferencesManager.h"

#define MENU_HEIGHT 5.0

//static NSImage * _shareScreenImage = nil;
//static NSImage * _shareScreenOnImage = nil;

@interface TPLayoutLocalScreenView : TPLayoutScreenView
@end

@implementation TPLayoutLocalScreenView

- (void)drawRect:(NSRect)rect
{
	TPLocalHost * localHost = (TPLocalHost*)[_hostView host];
	NSRect drawRect = [self bounds];
	NSScreen * screen = [self screen];
	NSImage * backgroundImage = [localHost backgroundImageForScreen:screen];
	if(backgroundImage != nil) {
#if FLIPPED_VIEW
		[backgroundImage setFlipped:YES];
#endif
		[backgroundImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
#if FLIPPED_VIEW
		[backgroundImage setFlipped:NO];
#endif
	}
	else {
		[[NSColor colorWithCalibratedRed:30.0/255.0 green:70.0/255.0 blue:140.0/255.0 alpha:1.0] set];
		[[NSBezierPath bezierPathWithRect:drawRect] fill];
	}
	
	if([self isMainScreen]) { // main screen
		NSRect menuRect = drawRect;
#if FLIPPEDVIEW
#else
		menuRect.origin.y += (menuRect.size.height - MENU_HEIGHT);
#endif
		menuRect.size.height = MENU_HEIGHT;
		[[NSGraphicsContext currentContext] saveGraphicsState];
		
		CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
		CGRect cgRect = *(CGRect*)(&drawRect);
		CGContextClipToRect(ctx, cgRect);
		NSShadow * shadow = [[NSShadow alloc] init];
		[shadow setShadowBlurRadius:2.0];
		[shadow setShadowColor:[NSColor blackColor]];
		[shadow setShadowOffset:NSMakeSize(0,-1)];
		[shadow set];
		
		float alpha;
		if([[_hostView host] osVersion] >= TPHostOSVersion(5)) {
			alpha = 0.8;
		}
		else {
			alpha = 1.0;
		}
		
		[[NSColor colorWithCalibratedWhite:1.0 alpha:alpha] set];
		[[NSBezierPath bezierPathWithRect:menuRect] fill];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
		NSRect titleRect = NSInsetRect(drawRect, 2.0, 2.0);
		[self drawHostTitleInRect:titleRect dimmed:NO/*(drawMode == DISABLED_MODE)*/];
	}
		
	[[NSColor colorWithCalibratedWhite:0.2 alpha:1.0] set];
	NSFrameRect(drawRect);
}

@end

@implementation TPLayoutLocalHostView

+ (Class)screenViewClass
{
	return [TPLayoutLocalScreenView class];
}

- (TPHost*)host
{
	return [TPLocalHost localHost];
}

- (unsigned)nearestScreenIndexForFrame:(NSRect)frame distance:(float*)distance position:(NSPoint*)hostPosition side:(TPSide*)side
{
	unsigned nearestScreenIndex = 0;
	float minDist = INFINITY;
	NSRect minGluedRect = NSZeroRect;
	TPSide minSide = TPUndefSide;	
	
	unsigned screenIndex = 0; 
	NSArray * screenViews = [self screenViews];
	NSEnumerator * screenViewsEnum = [screenViews objectEnumerator];
	TPLayoutLocalScreenView * localScreenView;
	
	while((localScreenView = [screenViewsEnum nextObject]) != nil) {
		NSRect screenFrame = [[localScreenView screen] frame];
		NSRect localRect = [self convertRect:[localScreenView frame] toView:[self superview]];

		// Calculate excluded sides
		TPSide excludedSides = TPUndefSide;
		if(NSIntersectsRect(frame, localRect)) {
			NSEnumerator * screenViewsEnum2 = [screenViews objectEnumerator];
			TPLayoutLocalScreenView * localScreenView2;
			while((localScreenView2 = [screenViewsEnum2 nextObject]) != nil) {
				NSRect screenFrame2 = [[localScreenView2 screen] frame];
				if(NSMinX(screenFrame2) == NSMaxX(screenFrame)) {
					excludedSides |= TPRightSide;
				}
				if(NSMaxX(screenFrame2) == NSMinX(screenFrame)) {
					excludedSides |= TPLeftSide;
				}
				if(NSMinY(screenFrame2) == NSMaxY(screenFrame)) {
					excludedSides |= TPTopSide;
				}
				if(NSMaxY(screenFrame2) == NSMinY(screenFrame)) {
					excludedSides |= TPBottomSide;
				}
			}			
		}
		
		NSRect gluedRect;
		TPSide side;
		float dist = TPGluedRect(&gluedRect, &side, localRect, frame, excludedSides);
		
		if(dist < minDist) {
			minDist = dist;
			nearestScreenIndex = screenIndex;
			minGluedRect = gluedRect;
			minSide = side;
		}
		
		screenIndex++;
	}
		
	if(distance != NULL) {
		*distance = minDist;
		*hostPosition = minGluedRect.origin;
		*side = minSide;
	}
	
	return nearestScreenIndex;
}

#if 0
+ (void)initialize
{
	if(self == [TPLayoutLocalHostView class]) {
		NSString * imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"sharedscreen.tiff"];
		_shareScreenImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
		
		imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"sharedscreen-on.tiff"];
		_shareScreenOnImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
	}
}

- (BOOL)_canChooseSharedScreen
{
	NSArray * screens = [[TPLocalHost localHost] screens];
	return ([_layoutView isActive] && [screens count] > 1 && [[TPPreferencesManager sharedPreferencesManager] boolForPref:ALLOW_CONTROL]);
}

- (void)setScaleFactor:(float)inScaleFactor
{
    scaleFactor = inScaleFactor;
}

- (NSRect)rectForScreen:(NSScreen*)screen
{
	if(screen == nil)
		return NSZeroRect;
	
	NSRect screenRect = [screen frame];
	NSRect totalRect = [self totalRect];
	
	/* Recenter */
	screenRect.origin.x += (_origin.x - totalRect.origin.x);
	screenRect.origin.y += (_origin.y - totalRect.origin.y);
	
	return screenRect;
}

- (NSRect)drawRectForScreen:(NSScreen*)screen
{
	if(screen == nil)
		return NSZeroRect;
	
	NSRect screenRect = [self rectForScreen:screen];
	
	screenRect.origin.x = FORDRAW_ORIGIN(screenRect.origin.x*scaleFactor);
	screenRect.origin.y = FORDRAW_ORIGIN(screenRect.origin.y*scaleFactor);
	screenRect.size.width = FORDRAW_SIZE(screenRect.size.width*scaleFactor);
	screenRect.size.height = FORDRAW_SIZE(screenRect.size.height*scaleFactor);
	
	return screenRect;
}

- (NSRect)shareScreenRectFromDrawRect:(NSRect)drawRect
{
	return NSMakeRect(NSMaxX(drawRect) - 14.0, NSMaxY(drawRect) - 14.0, 12.0, 12.0);
}


- (NSRect)totalRect
{
	TPLocalHost * localHost = (TPLocalHost*)[self host];
	NSRect enclosingRect = NSZeroRect;
	unsigned screenIndex = 0; 
	NSScreen * screen;
	
	while(screen = [localHost screenAtIndex:screenIndex++]) {
		NSRect screenRect = [screen frame];
	
		enclosingRect = NSUnionRect(enclosingRect, screenRect);
	}
	
	return enclosingRect;
}

- (NSSize)totalSize
{
	return [self totalRect].size;
}

- (BOOL)isPointInside:(NSPoint)point
{
	unsigned screenIndex = 0; 
	NSScreen * screen;
	
	while(screen = [[self host] screenAtIndex:screenIndex++]) {
		NSRect drawRect = [self drawRectForScreen:screen];
		if(NSPointInRect(point, drawRect)) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)handleMouseDownAtPoint:(NSPoint)point
{
	if([self _canChooseSharedScreen]) {
		_insideScreen = [self screenAtPoint:point];
		if(_insideScreen != nil) {
			NSRect drawRect = [self drawRectForScreen:_insideScreen];
			NSRect shareScreenRect = [self shareScreenRectFromDrawRect:drawRect];
			if(NSPointInRect(point, shareScreenRect)) {
				_insideButton = YES;
				return YES;
			}
		}
	}
	
	return NO;
}

- (void)handleMouseDraggedAtPoint:(NSPoint)point
{
	if(_insideScreen != nil) {
		NSRect drawRect = [self drawRectForScreen:_insideScreen];
		NSRect shareScreenRect = [self shareScreenRectFromDrawRect:drawRect];
		_insideButton = NSPointInRect(point, shareScreenRect);
	}
}

- (void)handleMouseUpAtPoint:(NSPoint)point
{
	if(_insideScreen != nil) {
		NSRect drawRect = [self drawRectForScreen:_insideScreen];
		NSRect shareScreenRect = [self shareScreenRectFromDrawRect:drawRect];
		if(NSPointInRect(point, shareScreenRect)) {
			[(TPLocalHost*)[self host] setSharedScreenIndex:[[[TPLocalHost localHost] screens] indexOfObject:_insideScreen]];
		}
	}
	
	_insideButton = NO;
}

- (NSScreen*)screenAtPoint:(NSPoint)point
{
	TPLocalHost * localHost = (TPLocalHost*)[self host];
	unsigned screenIndex = 0;
	NSScreen * screen = nil;
	
	while((screen = [localHost screenAtIndex:screenIndex++]) != nil) {
		NSRect drawRect = [self drawRectForScreen:screen];
		if(NSPointInRect(point, drawRect)) {
			break;
		}
	}
	
	return screen;
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
	if([self _canChooseSharedScreen]) {
		TPLocalHost * localHost = [TPLocalHost localHost];
		NSMenu * menu = [[NSMenu alloc] init];
		
		NSString * title = NSLocalizedStringFromTableInBundle(@"Screen to share", nil, [NSBundle bundleForClass:[self class]], nil);
		NSMenuItem * titleMenuItem = [menu addItemWithTitle:title action:nil keyEquivalent:@""];
		[titleMenuItem setEnabled:NO];
		
		NSArray * screens = [localHost screens];
		unsigned sharedScreenIndex = [(TPLocalHost*)[self host] sharedScreenIndex];
		unsigned i;
		for(i=0; i<[screens count]; i++) {
			NSScreen * screen = [screens objectAtIndex:i];
			NSSize screenSize = [screen frame].size;
			NSString * title = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Screen %d - %.0fx%.0f", nil, [NSBundle bundleForClass:[self class]], nil), i+1, screenSize.width, screenSize.height];
			NSMenuItem * screenMenuItem = [menu addItemWithTitle:title action:@selector(changeSharedScreen:) keyEquivalent:@""];
			[screenMenuItem setTag:i];
			[screenMenuItem setState:(i==sharedScreenIndex)?NSOnState:NSOffState];
			[screenMenuItem setTarget:self];
		}
		
		return [menu autorelease];
	}
	else {
		return [super menuForEvent:event];
	}
}

- (void)changeSharedScreen:(NSMenuItem*)sender
{
	[(TPLocalHost*)[self host] setSharedScreenIndex:[sender tag]];
}
#endif
@end
