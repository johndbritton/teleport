//
//  TPOptionsView.m
//  teleport
//
//  Created by Julien Robert on 16/01/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPOptionsView.h"
#import "TPBezierPath.h"
#import "TPRemoteHost.h"

@implementation TPOptionsView

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	
#if 0
	if ([self respondsToSelector:@selector(setAppearance:)]) {
		[self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameLightContent]];
	}
#endif
	
	NSShadow * shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:2.0];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
	[shadow setShadowOffset:NSMakeSize(0.0, -2.0)];
	[self setShadow:shadow];
	
	return self;
}

- (void)drawRect:(NSRect)rect
{
	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
	
//	TPRemoteHost * remoteHost = (TPRemoteHost*)[hostController content];
	
//	NSData * data = [remoteHost backgroundImageData];
//	if(data != nil) {
//		CGContextScaleCTM(ctx, 1.0, -1.0);
//		NSImage * backgroundImage = [[NSImage alloc] initWithData:data];
//		NSRect adjustedRect = [self bounds];
//		adjustedRect.origin.y -= NSHeight(adjustedRect);
//		[backgroundImage drawInRect:adjustedRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//		[backgroundImage release];
//	}
//	
//	CGContextScaleCTM(ctx, 1.0, -1.0);

//	NSBezierPath * path = [NSBezierPath bezierPathWithRect:[self bounds]];
	[NSBezierPath drawRect:[self bounds] withGradientFrom:[NSColor underPageBackgroundColor] to:[NSColor windowBackgroundColor]];
	
//	
//	CGContextSetGrayFillColor(ctx, 0.9, 0.85);
	CGRect strokeRect = NSRectToCGRect(NSInsetRect([self bounds], 0.5, 0.5));
	CGContextSetLineWidth(ctx, 1.0);
	
	CGContextSetGrayStrokeColor(ctx, 0.7, 1.0);
	CGContextStrokeRect(ctx, strokeRect);
	
	strokeRect = CGRectInset(strokeRect, 1.0, 1.0);
	CGContextSetGrayStrokeColor(ctx, 1.0, 1.0);
	CGContextStrokeRect(ctx, strokeRect);
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

@end
