//
//  TPConnectionController.h
//  teleport
//
//  Created by JuL on Thu Jan 08 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DISCONNECT_WHEN_STOP_CONTROL 0

@class TPNetworkConnection, TPMessage, TPEventsController, TPHotBorder, TPRemoteHost;

extern NSString * TPScreenIndexKey;
extern NSString * TPScreenPlacementKey;
extern NSString * TPMousePositionKey;
extern NSString * TPSwitchOptionsKey;
extern NSString * TPDraggedPathsKey;
extern NSString * TPDragImageKey;
extern NSString * TPDragImageLocationKey;

@interface TPConnectionController : NSObject
{
	IBOutlet id delegate;
	TPNetworkConnection * _currentConnection;
	TPEventsController * _eventsController;
}

@property (nonatomic, strong) TPNetworkConnection *currentConnection;
- (void)updateEventsController;
@property (nonatomic, readonly, strong) TPEventsController *eventsController;
@property (nonatomic, readonly, strong) TPHotBorder *currentHotBorder;

- (void)setupHotBorder:(TPHotBorder*)hotBorder forHost:(TPRemoteHost*)host;
- (void)takeDownHotBorder:(TPHotBorder*)hotBorder;
- (BOOL)hotBorder:(TPHotBorder*)hotBorder firedAtLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo;

- (void)playSwitchSound;

- (void)stopControl;
- (void)stopControlWithDisconnect:(BOOL)disconnect;

- (id)optionForRemoteHost:(TPRemoteHost*)remoteHost key:(NSString*)key;

- (void)addDraggingInfo:(id<NSDraggingInfo>)draggingInfo toInfoDict:(NSMutableDictionary*)infoDict;
- (void)beginTransfersWithInfoDict:(NSDictionary*)infoDict;

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message;

@end
