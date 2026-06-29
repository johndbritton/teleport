//
//  TPLayoutHost.m
//  teleport
//
//  Created by JuL on Sun Feb 29 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPLayoutHostView.h"
#import "TPHost.h"
#import "TPHostsManager.h"

#define TEXT_MARGIN 6

@implementation NSBezierPath (TeleportAdditions)

+ (void)drawRect:(NSRect)rect withGradientFrom:(NSColor*)colorStart to:(NSColor*)colorEnd 
{
	float fraction = 0;
	float height = rect.size.height - 1;
	float width = rect.size.width;
	float step = 1/height;
	int i;
	
	NSRect gradientRect = NSMakeRect(rect.origin.x, rect.origin.y, width, 1.0);
	[colorEnd set];
	[NSBezierPath fillRect:gradientRect];
	
	for(i = 0; i < height; i++)
	{
		gradientRect.origin.y++;
		NSColor * gradientColor = [colorStart blendedColorWithFraction:fraction ofColor:colorEnd];
		[gradientColor set];
		[NSBezierPath fillRect:gradientRect];
		fraction += step;
	}
} 

@end

@implementation TPLayoutScreenView

- (instancetype) initWithHostView:(TPLayoutHostView*)hostView screenIndex:(unsigned)screenIndex
{
	self = [super initWithFrame:NSZeroRect];
	
	_hostView = hostView;
	_screenIndex = screenIndex;
	
	return self;
}


- (TPLayoutHostView*)hostView
{
	return _hostView;
}

- (NSScreen*)screen
{
	NSArray * screens = [[_hostView host] screens];
	if(_screenIndex < [screens count]) {
		return screens[_screenIndex];
	}
	else {
		return nil;
	}
}

- (unsigned)screenIndex
{
	return _screenIndex;
}

- (BOOL)isMainScreen
{
	return ([self screenIndex] == 0);
}

- (void)update
{
	
}

- (void)drawHostTitleInRect:(NSRect)rect dimmed:(BOOL)dimmed
{
	if(NSWidth(rect) < 1.0 || NSHeight(rect) < 1.0)
		return;
	
	NSImage * image = [[NSImage alloc] initWithSize:rect.size];
	[image setFlipped:YES];
	[image lockFocus];
	
	/* Create attributed string */
	NSColor * fontColor;
	if(dimmed)
		fontColor = [[NSColor whiteColor] colorWithAlphaComponent:0.5];
	else
		fontColor = [NSColor whiteColor];
	
	NSShadow * shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:3.0];
	[shadow setShadowColor:[NSColor blackColor]];
	[shadow setShadowOffset:NSMakeSize(1.0,-1.0)];
	
	NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setAlignment:NSCenterTextAlignment];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	//	[paragraphStyle setLineSpacing:-20.0];
	
	CGFloat fontSize = MIN([NSFont systemFontSize], rect.size.height / 4);
	NSDictionary * attributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:fontSize],
								 NSShadowAttributeName: shadow,
								 NSForegroundColorAttributeName: fontColor,
								 NSParagraphStyleAttributeName: paragraphStyle};
	
	NSAttributedString * attString = [[NSAttributedString alloc] initWithString:[[_hostView host] computerName] attributes:attributes];
	
	/* Layout */
	NSLayoutManager * layoutManager = [[NSLayoutManager alloc] init];
	NSTextContainer * textContainer = [[NSTextContainer alloc] initWithContainerSize:rect.size];
	NSTextStorage * textStorage = [[NSTextStorage alloc] initWithAttributedString:attString];
	
	[layoutManager addTextContainer:textContainer];
	
	[textStorage addLayoutManager:layoutManager];
	
	
	NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	
	NSRect usedRect = [layoutManager usedRectForTextContainer:textContainer];
	
	CGFloat hostNameY = roundf((NSHeight(rect) - NSHeight(usedRect)) / 2.0) - 8.0;
	[layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:NSMakePoint(1.0, hostNameY)];
	
	NSString *ipAddress = [[_hostView host] address];
	NSDictionary * ipAttributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:fontSize * 0.7],
		NSShadowAttributeName: shadow,
		NSForegroundColorAttributeName: fontColor,
		NSParagraphStyleAttributeName: paragraphStyle
	};

	NSAttributedString * ipString = [[NSAttributedString alloc] initWithString:ipAddress attributes:ipAttributes];
	// IP address layout
	NSLayoutManager *ipLayout = [[NSLayoutManager alloc] init];
	NSTextContainer *ipContainer = [[NSTextContainer alloc] initWithContainerSize:rect.size];
	NSTextStorage *ipStorage = [[NSTextStorage alloc] initWithAttributedString:ipString];
	[ipLayout addTextContainer:ipContainer];
	[ipStorage addLayoutManager:ipLayout];

	NSRange ipGlyphRange = [ipLayout glyphRangeForTextContainer:ipContainer];
	NSRect ipUsedRect = [ipLayout usedRectForTextContainer:ipContainer];

	CGFloat ipY = hostNameY + NSHeight(usedRect) + 2.0; // draw just below host name
	[ipLayout drawGlyphsForGlyphRange:ipGlyphRange atPoint:NSMakePoint(1.0, ipY)];
	
	[image unlockFocus];
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
	[shadow set];
	[image drawAtPoint:rect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end

@implementation TPLayoutHostView

+ (Class)screenViewClass
{
	return [TPLayoutScreenView class];
}

+ (id)defaultAnimationForKey:(NSString *)key
{
	if([key isEqualToString:NSAnimationTriggerOrderIn] || [key isEqualToString:NSAnimationTriggerOrderOut]) {
		return nil;
	}
	else if([key isEqualToString:@"frameOrigin"]) {
		CAAnimation * animation = [CABasicAnimation animation];
		animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		return animation;
	}
	else {
		return [super defaultAnimationForKey:key];
	}
}

- (instancetype) initWithHost:(TPHost*)host layoutView:(TPLayoutView*)layoutView
{
	self = [super initWithFrame:NSZeroRect];
	
	_hostIdentifier = [[host identifier] copy];
	_layoutView = layoutView;
	
	NSArray * screens = [host screens];
	NSEnumerator * screensEnum = [screens objectEnumerator];
	TPScreen * screen;	
	Class screenViewClass = [[self class] screenViewClass];
	
	unsigned screenIndex = 0;
	while((screen = [screensEnum nextObject])) {
		NSView * screenView = [(TPLayoutScreenView*)[screenViewClass alloc] initWithHostView:self screenIndex:screenIndex];
		[self addSubview:screenView];
		screenIndex++;
	}
	
	NSShadow * shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:2.0];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
	[shadow setShadowOffset:NSMakeSize(0,-1)];
	[self setShadow:shadow];

	
	return self;
}


- (void)setHostIdentifier:(NSString*)hostIdentifier
{
	if(hostIdentifier != _hostIdentifier) {
		_hostIdentifier = hostIdentifier;
	}
}

- (NSString*)hostIdentifier
{
	return _hostIdentifier;
}

- (TPHost*)host
{
	return [[TPHostsManager defaultManager] hostWithIdentifier:_hostIdentifier];
}

- (NSRect)totalFrame
{
	NSArray * screens = [[self host] screens];
	NSRect enclosingRect = NSZeroRect;
	NSEnumerator * screensEnum = [screens objectEnumerator];
	TPScreen * screen;	
	
	while((screen = [screensEnum nextObject])) {
		NSRect screenRect = [screen frame];
		enclosingRect = NSUnionRect(enclosingRect, screenRect);
	}
	
	return enclosingRect;
}

- (NSArray*)screenViews
{
	return [self subviews];
}

- (unsigned)indexOfScreenAtPoint:(NSPoint)point
{
	NSEnumerator * screenViewsEnum = [[self screenViews] objectEnumerator];
	TPLayoutScreenView * screenView;
	while((screenView = [screenViewsEnum nextObject]) != nil) {
		if(NSPointInRect(point, [screenView frame])) {
			return [screenView screenIndex];
		}
	}
	
	return -1;
}

- (TPLayoutScreenView*)screenViewAtIndex:(unsigned)index
{
	NSScreen * screen = [[self host] screens][index];
	NSEnumerator * screenViewsEnum = [[self screenViews] objectEnumerator];
	TPLayoutScreenView * screenView;
	while((screenView = [screenViewsEnum nextObject]) != nil) {
		if([[screenView screen] isEqual:screen]) {
			return screenView;
		}
	}
	return nil;
}

- (NSRect)screenFrameAtIndex:(unsigned)index
{
	TPLayoutScreenView * screenView = [self screenViewAtIndex:index];
	NSRect frame = [screenView frame];
	frame = [self convertRect:frame toView:[self superview]];
	return frame;
}

- (NSRect)hostFrameFromScreenFrame:(NSRect)frame atIndex:(unsigned)index
{
	TPLayoutScreenView * screenView = [self screenViewAtIndex:index];
	NSRect hostFrame = [self frame];
	NSRect screenFrame = [screenView frame];
	hostFrame.origin.x = NSMinX(frame) - NSMinX(screenFrame);
	hostFrame.origin.y = NSMinY(frame) - NSMinY(screenFrame);
	return hostFrame;
}

- (void)updateLayoutWithScaleFactor:(float)scaleFactor
{
	NSRect totalFrame = [self totalFrame];
	
	NSRect scaledTotalFrame = TPScaledRect(totalFrame, scaleFactor);
	[self setFrameSize:scaledTotalFrame.size];

	[self layer].masksToBounds = NO;
	
	NSArray * screenViews = [self screenViews];
	NSEnumerator * screensEnum = [screenViews objectEnumerator];
	TPLayoutScreenView * screenView;	
	
	while((screenView = [screensEnum nextObject])) {
		NSScreen * screen = [screenView screen];
		NSRect screenFrame = [screen frame];
		NSRect scaledScreenFrame = TPScaledRect(screenFrame, scaleFactor);
		scaledScreenFrame.origin.x -= NSMinX(scaledTotalFrame);
		scaledScreenFrame.origin.y -= NSMinY(scaledTotalFrame);
		
		scaledScreenFrame.origin.x = floor(NSMinX(scaledScreenFrame));
		scaledScreenFrame.origin.y = floor(NSMinY(scaledScreenFrame));
		scaledScreenFrame.size.width = floor(NSWidth(scaledScreenFrame));
		scaledScreenFrame.size.height = floor(NSHeight(scaledScreenFrame));
		
		[screenView setFrame:scaledScreenFrame];
	}
}

@end
