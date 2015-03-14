

#import "TPBezierPath.h"

@implementation NSBezierPath (teleportAdditions)

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float) radius
{
	NSBezierPath * path = [NSBezierPath bezierPath];
	NSPoint topMid = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
	NSPoint topLeft = NSMakePoint(NSMinX(aRect), NSMaxY(aRect));
	NSPoint topRight = NSMakePoint(NSMaxX(aRect), NSMaxY(aRect));
	NSPoint bottomRight = NSMakePoint(NSMaxX(aRect), NSMinY(aRect));
	[path moveToPoint:topMid];
	[path appendBezierPathWithArcFromPoint:topLeft toPoint:aRect.origin radius:radius];
	[path appendBezierPathWithArcFromPoint:aRect.origin toPoint:bottomRight radius:radius];
	[path appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight radius:radius];
	[path appendBezierPathWithArcFromPoint:topRight toPoint:topLeft radius:radius];
	[path closePath];
	return path;
}

+ (void)fillLeftRoundedRectInRect:(NSRect)aRect radius:(float)radius
{
	if(aRect.size.width < 4)
		return;
	NSBezierPath * path = [NSBezierPath bezierPath];
	NSRect fullRect = aRect;
	fullRect.size.width += 16;
	NSPoint topMid = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
	NSPoint topLeft = NSMakePoint(NSMinX(aRect), NSMaxY(aRect));
	NSPoint topRight = NSMakePoint(NSMaxX(aRect), NSMaxY(aRect));
	NSPoint bottomRight = NSMakePoint(NSMaxX(aRect), NSMinY(aRect));
	[path moveToPoint:topMid];
	[path appendBezierPathWithArcFromPoint:topLeft toPoint:aRect.origin radius:radius];
	[path appendBezierPathWithArcFromPoint:aRect.origin toPoint:bottomRight radius:radius];
	[path appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight radius:0];
	[path appendBezierPathWithArcFromPoint:topRight toPoint:topLeft radius:0];
	[path closePath];
	[path fill];
	//NSEraseRect(NSMakeRect(aRect.origin.x+aRect.size.width, aRect.origin.y, 18, aRect.size.height));
}

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
