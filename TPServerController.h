//
//  TPServerController.h
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TPConnectionController.h"

typedef NS_ENUM(NSInteger, TPServerState) {
	TPServerIdleState,
	TPServerSharedState,
	TPServerControlledState
} ;

@class TPRemoteHost, TPHotBorder, TPMessage;

@interface TPServerController : TPConnectionController
{
	TPServerState _state;
	TPHotBorder * _clientHotBorder;
	NSDictionary * _switchOptions;
}

+ (TPServerController*)defaultController;

- (void)startSharing;
- (void)stopSharing;

- (void)requestedStartControlByHost:(TPRemoteHost*)host onConnection:(TPNetworkConnection*)connection withInfoDict:(NSDictionary*)infoDict;
- (void)startControlWithInfoDict:(NSDictionary*)infoDict;

- (void)requestStopControlAtLocation:(NSPoint)location withDraggingInfo:(id<NSDraggingInfo>)draggingInfo;
- (void)stopControlWithDisconnect:(BOOL)disconnect;

- (void)setSwitchOptions:(NSDictionary*)switchOptions;

@property (nonatomic) BOOL allowControl;
@property (nonatomic, getter=isControlled, readonly) BOOL controlled;

//- (void)sendPong;

@end
