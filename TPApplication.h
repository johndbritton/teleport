/* TPApplication */

#import <Cocoa/Cocoa.h>

@protocol TPEventDelegate <NSObject>

- (BOOL)applicationWillSendEvent:(NSEvent*)event;

@end

@interface TPApplication : NSApplication
{
	id<TPEventDelegate> _eventsDelegate;
}

- (void)setEventDelegate:(id<TPEventDelegate>)eventDelegate;

@end
