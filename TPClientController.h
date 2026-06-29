//
//  TPClientController.h
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPConnectionController.h"
#import "TPEventsController.h"

typedef NS_ENUM(NSInteger, TPClientState) {
	TPClientIdleState,
	TPClientConnectingState,
	TPClientControllingState
} ;

@class TPRemoteHost;

@interface TPClientController : TPConnectionController <TPEventsListener>
{
	TPClientState _state;
	NSMutableDictionary * _hotBorders;
	NSMutableDictionary * _hotKeys;
	NSDictionary * _infoDict;

	io_object_t _sleepNotifier;
	io_connect_t _sleepService;
	IONotificationPortRef _sleepNotifyPortRef;
}

+ (TPClientController*)defaultController;

- (void)updateTriggersAndShowVisualHint:(BOOL)showVisualHint;

- (BOOL)requestStartControlOnHost:(TPRemoteHost*)remoteHost atLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo;
- (void)sendStartControlRequestForConnection:(TPNetworkConnection*)connection withInfoDict:(NSDictionary*)infoDict;
- (void)startControl;

- (void)requestedStopControlWithInfoDict:(NSDictionary*)infoDict;
- (void)stopControlWithDisconnect:(BOOL)disconnect;
@property (nonatomic, getter=isControlling, readonly) BOOL controlling;

@end
