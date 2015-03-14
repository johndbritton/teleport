//
//  TPDirectEventTapsController.m
//  teleport
//
//  Created by Julien Robert on 01/08/07.
//  Copyright 2007 abyssoft. All rights reserved.
//

#import "TPDirectEventTapsController.h"
#import "TPEventTapsController_Internal.h"

//typedef uint16_t    CGSKeyCode;
//typedef uint16_t    CGSCharCode;
//typedef uint32_t CGSEventMask;
//typedef uint32_t CGSEventTime;    /* ticks, or about 1/60 second */
//typedef uint64_t CGSEventRecordTime;  /* nanosecond timer */
//typedef uint16_t CGSEventRecordVersion;
//typedef uint32_t CGSEventType;
//typedef uint32_t CGSByteCount;	/* Should be `size_t'. */
//typedef uint32_t CGSEventFlag;
//typedef uint32_t CGSConnectionID;
//typedef uint32_t CGSWindowID;
//typedef unsigned char CGSBoolean;
//
//
///* Finally: The event record! */
//struct _CGSEventRecord {
//    CGSEventRecordVersion major;
//    CGSEventRecordVersion minor;
//    CGSByteCount length;        /* Length of complete event record */
//    CGSEventType type;          /* An event type from above */
//    CGPoint location;           /* Base coordinates (global), from upper-left */
//    CGPoint windowLocation;     /* Coordinates relative to window */
//    CGSEventRecordTime time;    /* nanoseconds since startup */
//    CGSEventFlag flags;         /* key state flags */
//    CGSWindowID window;         /* window number of assigned window */
//    CGSConnectionID connection; /* connection the event came from, or that owns the window */
//    /* New for 10.4 */
//	
//	UInt8 pad1[40];
//	UInt8 pad2[20];
//	UInt8 pad3[72];
//#ifdef __LP64__
//    void *      ioEventData;    /* TEMPORARY; used in server while converting to new format; gone in 10.6 */
//#else
//    void *      ioEventData;    /* TEMPORARY; used in server while converting to new format; gone in 10.6 */
//    uint32_t   _padding __attribute__ ((deprecated));   /* Preserve alignment, reserved for future use */
//#endif
//    /* New for 10.5: Values used to map global and window coordinates between Quadrant I and III */
//    uint16_t   windowHeight;   /* Height of window in 'window' field */
//    uint16_t   mainDisplayHeight;   /* Height of main display */
//    uint16_t  *unicodePayload; /* TEMPORARY: Unicode payload, valid only while CGEventRef container exists; gone in 10.6 */
//	
//    /* New for 10.7: connection that gets events for window (as opposed to that owns the window).
//     * They are different in the case of cross-process window hosting.
//     */
//    CGSConnectionID eventOwner;
//    /* Also new for 10.7: a flag to indicate whether a click passed through an event-transparent window */
//    CGSBoolean passedThrough;
//};
//
//typedef struct _CGSEventRecord CGSEventRecord;
//
//extern uint32_t CGEventGetEventRecordSize(CGEventRef event);
//extern CGError CGEventGetEventRecord(CGEventRef event, CGSEventRecord * eventRecord, uint32_t eventRecordSize);
//extern CGError CGEventSetEventRecord(CGEventRef event, CGSEventRecord * eventRecord, uint32_t eventRecordSize);

#define CGIsMouseEventType(event) (event == kCGEventMouseMoved) || (event == kCGEventLeftMouseDragged) || (event == kCGEventRightMouseDragged) || (event == kCGEventOtherMouseDragged)

static TPDirectEventTapsController * _eventTapsController = nil;

@implementation TPDirectEventTapsController

+ (TPEventsController*)defaultController
{
	if(_eventTapsController == nil)
		_eventTapsController = [[TPDirectEventTapsController alloc] init];
	return _eventTapsController;
}

- (NSData*)_eventDataFromEvent:(id)e
{
	CGEventRef event = (__bridge CGEventRef)e;

	
//    CGSEventRecord eventRecord;
//    
//    uint32_t size = CGEventGetEventRecordSize(event);
//	
//    CGEventGetEventRecord(event, &eventRecord, size);
//    eventRecord.ioEventData = NULL;
//    
//    CGEventSetEventRecord(event, &eventRecord, size);
//	
	NSData * eventData = (NSData*)CFBridgingRelease(CGEventCreateData(NULL, event));
	
	return eventData;
}

- (void)_postEventWithEventData:(NSData*)eventData
{
	if([eventData length] == 0) return;
	CGEventRef event = CGEventCreateFromData(NULL, (__bridge CFDataRef)eventData);
	CGEventType eventType = CGEventGetType(event);
	
	//DebugLog(@"post event %@", [TPEventTapsController _eventNameFromType:eventType]);
	
	if(CGIsMouseEventType(eventType)) {
		int64_t deltaX = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
		int64_t deltaY = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
		
		if(deltaX != 0 || deltaY != 0) {
			TPMouseDelta mouseDelta = {deltaX, deltaY};
			[self _updateMouseLocationWithMouseDelta:mouseDelta];
			
			//DebugLog(@"mouseDelta=%f %f mouseLocation=%f %f", mouseDelta.x, mouseDelta.y, _currentMouseLocation.x, _currentMouseLocation.y);
		}
	}
	
	CGEventSetLocation(event, _currentMouseLocation);
		
	[self _postEvent:event];
	CFRelease(event);
}

@end
