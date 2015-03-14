#import "TPVerticalView.h"
#import "TPRemoteHost.h"
#import "TPLayoutHost.h"
#import "TPPreferencePane.h"

#define HOST_MARGIN 4

@implementation TPVerticalView

- (void)drawRect:(NSRect)rect
{
    [super drawBackground];
    
    NSEnumerator * hostsEnum = [dataSource objectEnumerator];
    TPRemoteHost * host;
    NSPoint drawPoint = NSMakePoint(HOST_MARGIN, HOST_MARGIN);
    while(host = [hostsEnum nextObject]) {
        NSSize drawSize = [host drawSize];
        [host drawHostAtPoint:drawPoint usingMode:SLAVE_HOST_MODE];
        drawPoint.x += drawSize.width + HOST_MARGIN;
    }
    
    //NSLog(@"draw");
    /* Draw text */
    [super drawString:toloc(@"Controllable hosts")];
}

- (void)setDataSource:(NSArray*)pDataSource
{
    dataSource = [pDataSource retain];
}



- (BOOL)isFlipped
{
    return NO;
}

@end
