//
//  TPBezelView.m
//  Teleport
//
//  Created by JuL on Fri Dec 12 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPBezelView.h"
#import "TPBezierPath.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"
#import "TPPreferencesManager.h"

#define Y_TITLE_MARGIN 64.0
#define X_TITLE_MARGIN 16.0
#define Y_TEXT_MARGIN 32.0
#define Y_ICON_ADJUSTMENT 24.0
#define MIN_ROUNDED_RECT_SIZE 214.0
#define ROUNDED_RECT_RADIUS 24.0
#define ARROW_SIZE 14.0
#define ARROW_MARGIN (ARROW_SIZE/2.0 + 8.0)
#define WINDOW_TRANSPARENCY 0.15

#define PROGRESSBAR_MARGIN 14.0
#define PROGRESSBAR_INTERNAL_MARGIN 2.0
#define PROGRESSBAR_HEIGHT 10.0

static NSImage * _teleportImage = nil;
static NSImage * _lockImage = nil;
static NSDictionary * _titleAttributes = nil;
static NSDictionary * _textAttributes = nil;

@implementation TPBezelView

+ (void)initialize
{
	if(self == [TPBezelView class]) {
		_teleportImage = [NSImage imageNamed:@"whitelogo"];
		_lockImage = [NSImage imageNamed:@"Lock_White"];
		
		NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
		[paragraphStyle setAlignment:NSCenterTextAlignment];
		_titleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
							[NSFont fontWithName:@"Arial Black" size:18], NSFontAttributeName,
							[NSColor whiteColor], NSForegroundColorAttributeName,
							paragraphStyle, NSParagraphStyleAttributeName,
							nil];
		_textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
						   [NSFont fontWithName:@"Arial Black" size:13], NSFontAttributeName,
						   [NSColor whiteColor], NSForegroundColorAttributeName,
						   paragraphStyle, NSParagraphStyleAttributeName,
						   nil];
	}
}

- (instancetype) init
{
	self = [super init];

	_text = nil;
	_remoteHost = nil;

	return self;
}

- (NSString*)_title
{
	return [_remoteHost computerName];
}

- (void)_update
{
	NSSize titleSize = [[self _title] sizeWithAttributes:_titleAttributes];
	
	float width = round(MAX(MIN_ROUNDED_RECT_SIZE, titleSize.width + 2*X_TITLE_MARGIN));

	NSWindow * window = [self window];
	
	NSRect frame = [[_remoteHost localScreen] frame];
	
	frame.origin.x = NSMinX(frame) + round((NSWidth(frame) - width)/2.0);
	frame.origin.y = NSMinY(frame) + round((NSHeight(frame) - MIN_ROUNDED_RECT_SIZE)/2.0);
	frame.size = NSMakeSize(width, MIN_ROUNDED_RECT_SIZE);
	
	[self setNeedsDisplay:YES];
	[window setFrame:frame display:YES animate:NO];
}

- (void)setRemoteHost:(TPRemoteHost*)remoteHost
{
	if(remoteHost != _remoteHost) {
		[_indeterminateTimer invalidate];
		_indeterminateTimer = nil;
		
		_remoteHost = remoteHost;
	}
	
	[self _update];
}

- (void)setText:(NSString*)text
{
	if(text != _text) {
		_text = [text copy];
		
		if(text == nil) {
			[_indeterminateTimer invalidate];
			_indeterminateTimer = nil;
		}

		[self _update];
	}
}

- (void)setShowProgress:(BOOL)showProgress
{
	if(_showProgress != showProgress) {
		_showProgress = showProgress;
		
		if(!showProgress) {
			[_indeterminateTimer invalidate];
			_indeterminateTimer = nil;
		}
		
		[self setNeedsDisplay:YES];
	}
}

- (void)setProgress:(float)progress
{
	if(_progress != progress) {
		_progress = progress;
		
		[self setNeedsDisplay:YES];
	}
}

- (void)_progressIndeterminateTimer:(NSTimer*)timer
{
	_indeterminateDelta++;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
	[[NSBezierPath bezierPathWithRect:rect] fill];
	
	NSRect bounds = [self bounds];
	
	/* Draw rounded rect */
	[[NSColor colorWithCalibratedWhite:0.0 alpha:WINDOW_TRANSPARENCY] set];
	[[NSBezierPath bezierPathWithRoundRectInRect:bounds radius:ROUNDED_RECT_RADIUS] fill];
	
	/* Draw icon */
	NSPoint imagePoint = bounds.origin;
	NSSize imageSize = [_teleportImage size];
	imagePoint.x += round((NSWidth(bounds) - imageSize.width)/2.0);
	imagePoint.y += round((NSHeight(bounds) - imageSize.height + (Y_TITLE_MARGIN - Y_ICON_ADJUSTMENT))/2.0);
	[_teleportImage drawAtPoint:imagePoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	/* Create arrow */
	NSBezierPath * arrow = [NSBezierPath bezierPath];
	[arrow moveToPoint:NSZeroPoint];
	[arrow lineToPoint:NSMakePoint(0, ARROW_SIZE)];
	[arrow lineToPoint:NSMakePoint(ARROW_SIZE, ARROW_SIZE/2)];
	[arrow closePath];
	
	/* Setup shadow */
	NSShadow * shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:4.0];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.8]];
	[shadow setShadowOffset:NSMakeSize(1.5,-1.5)];
	[shadow set];
	
	/* Position and draw arrow */
	NSAffineTransform * transform = [NSClassFromString(@"NSAffineTransform") transform]; // to preserve 10.3 compatibility
	
	NSRect localRect = [[_remoteHost localScreen] frame];
	NSRect hostRect = [_remoteHost adjustedHostRect];
	float h = NSMidX(hostRect) - NSMidX(localRect);
	float v = NSMidY(hostRect) - NSMidY(localRect);
	float angle = atan2f(v, h);
	
	[transform translateXBy:NSMidX(bounds) yBy:NSMidY(bounds)];
	[transform rotateByRadians:angle];
	[transform translateXBy:-ARROW_SIZE/2.0 yBy:-ARROW_SIZE/2.0];
	
	float width = NSWidth(bounds)/2.0;
	float height = NSHeight(bounds)/2.0;
	float limitAngle = atan2f(height, width);
	float translate;
	
	if(angle >= M_PI/2.0) {
		angle = M_PI - angle;
	}
	else if(angle < 0.0 && angle >= -M_PI/2.0) {
		angle = -angle;
	}
	else if(angle < 0.0) {
		angle = angle + M_PI;
	}
	
	if(angle < limitAngle) {
		translate = width/cosf(angle);
	}
	else {
		translate = height/sinf(angle);
	}
	
	[transform translateXBy:round(translate - ARROW_MARGIN) yBy:0.0];

	[arrow transformUsingAffineTransform:transform];
	
	[[NSColor whiteColor] set];
	[arrow fill];
	
	/* Draw title */
	NSRect titleRect = bounds;
	titleRect.origin.y -= (NSHeight(bounds) - Y_TITLE_MARGIN);
	[[self _title] drawInRect:titleRect withAttributes:_titleAttributes];
	
	/* Eventually draw lock image */
	if(_remoteHost != nil && [[TPLocalHost localHost] pairWithHost:_remoteHost hasCapability:TPHostEncryptionCapability]) {
		NSPoint lockPoint = NSMakePoint(NSMaxX(bounds) - 26.0, NSMaxY(bounds) - 26.0);
		[_lockImage drawAtPoint:lockPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	/* Update timer */
	BOOL needTimer = _showProgress && (_progress == -1.0);
	if(needTimer && (_indeterminateTimer == nil)) {
		_indeterminateTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(_progressIndeterminateTimer:) userInfo:nil repeats:YES];
	}
	else if(!needTimer && (_indeterminateTimer != nil)) {
		[_indeterminateTimer invalidate];
		_indeterminateTimer = nil;

	}
		
	/* Eventually draw progress bar or text */
	if(_text != nil) {
		NSRect textRect = bounds;
		textRect.origin.y -= (NSHeight(bounds) - Y_TEXT_MARGIN);
		
		[_text drawInRect:textRect withAttributes:_textAttributes];
	}
	else if(_showProgress) {
		NSRect progressBarRect = bounds;
		progressBarRect.origin.x += PROGRESSBAR_MARGIN;
		progressBarRect.origin.y += PROGRESSBAR_MARGIN;
		progressBarRect.size.width -= 2*PROGRESSBAR_MARGIN;
		progressBarRect.size.height = PROGRESSBAR_HEIGHT;
		
		NSImage * progressImage = [[NSImage alloc] initWithSize:progressBarRect.size];
		[progressImage lockFocus];
		
		[[NSColor whiteColor] set];
		NSRect strokeRect = progressBarRect;
		strokeRect.origin = NSZeroPoint;
		NSBezierPath * path = [NSBezierPath bezierPathWithRect:strokeRect];
		[path setLineWidth:2.0];
		[path stroke];
		
		NSRect fillRect = strokeRect;
		fillRect.origin.x += PROGRESSBAR_INTERNAL_MARGIN;
		fillRect.origin.y += PROGRESSBAR_INTERNAL_MARGIN;
		fillRect.size.width -= 2*PROGRESSBAR_INTERNAL_MARGIN;
		fillRect.size.height -= 2*PROGRESSBAR_INTERNAL_MARGIN;
		
		if(_progress > 0.0) {
			fillRect.size.width *= _progress;
			
			[[NSColor whiteColor] set];
		}
		else if(_progress == -1.0) {
			static NSImage * patternImage = nil;
			if(patternImage == nil) {
#define LINE_WIDTH 4
				CGFloat dim = 2 * LINE_WIDTH * NSHeight(fillRect);
				patternImage = [[NSImage alloc] initWithSize:NSMakeSize(dim, dim)];
				[patternImage lockFocus];
				
				[[NSColor whiteColor] set];
				
				CGFloat x = -dim;
				while(x < dim) {
					NSBezierPath * path = [[NSBezierPath bezierPath] init];
					[path moveToPoint:NSMakePoint(-x - LINE_WIDTH, 0.0)];
					[path lineToPoint:NSMakePoint(-x, 0.0)];
					[path lineToPoint:NSMakePoint(-x + dim, dim)];
					[path lineToPoint:NSMakePoint(-x - LINE_WIDTH + dim, dim)];
					[path closePath];
					[path fill];
					
					x += 2 * LINE_WIDTH;
				}
				
				[patternImage unlockFocus];
			}
									
			[[NSGraphicsContext currentContext] setPatternPhase:NSMakePoint(_indeterminateDelta % (2 * LINE_WIDTH), 0.0)];
			
			[[NSColor colorWithPatternImage:patternImage] set];
		}
		
		[[NSBezierPath bezierPathWithRect:fillRect] fill];
		
		[progressImage unlockFocus];
		[progressImage drawAtPoint:progressBarRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
}

@end
