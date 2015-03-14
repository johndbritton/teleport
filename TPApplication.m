#import "TPApplication.h"

@implementation TPApplication

- (void)setEventDelegate:(id<TPEventDelegate>)eventDelegate
{
	_eventsDelegate = eventDelegate;
}

- (void)sendEvent:(NSEvent *)event
{
	BOOL sendToSuper = YES;
	
//	DebugLog(@"sendEvent: %@ (%d)", event, [event type]);
	
	if(_eventsDelegate != nil && [_eventsDelegate respondsToSelector:@selector(applicationWillSendEvent:)]) {
		if(![_eventsDelegate applicationWillSendEvent:event])
			sendToSuper = NO;
	}
	
	if(sendToSuper)
		[super sendEvent:event];
}

@end
