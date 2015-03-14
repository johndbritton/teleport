/* TPVerticalView */

#import <Cocoa/Cocoa.h>
#import "TPView.h"

#define TPControlDragType @"TPControlDragType"

@class TPRemoteHost;

@interface TPVerticalView : TPView
{
    TPRemoteHost * draggingHost;
    NSArray * dataSource;
    IBOutlet id delegate;
}

- (void)setDataSource:(NSArray*)pDataSource;
- (NSPoint)dragPointForHost:(TPRemoteHost*)pHost;

@end
