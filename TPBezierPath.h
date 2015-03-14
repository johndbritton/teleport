

#import <Foundation/Foundation.h>


@interface NSBezierPath (teleportAdditions)

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)rect radius:(float)radius;
+ (void)fillLeftRoundedRectInRect:(NSRect)aRect radius:(float)radius;
+ (void)drawRect:(NSRect)rect withGradientFrom:(NSColor*)colorStart to:(NSColor*)colorEnd;

@end
