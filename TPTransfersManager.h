//
//  TPTransfersManager.h
//  teleport
//
//  Created by JuL on 26/07/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TPTCPSocket;
@class TPNetworkConnection;
@class TPTransfer;
@class TPOutgoingTransfer;

@interface TPTransfersManager : NSObject
{
	NSMutableDictionary * _outgoingTransfers;
	NSMutableDictionary * _incomingTransfers;
	
	NSMutableDictionary * _outgoingConnections;
	NSMutableArray * _transferRequests;
	
	BOOL _requestInProcess;
	BOOL _lastTransferWasCancelled;
	
	id _delegate;
}

+ (TPTransfersManager*)manager;

- (void)setDelegate:(id)delegate;

- (void)beginTransfer:(TPOutgoingTransfer*)transfer usingConnection:(TPNetworkConnection*)connection;
- (void)startTransferWithUID:(NSString*)transferUID usingConnection:(TPNetworkConnection*)connection onPort:(int)port;
- (void)abortTransferWithUID:(NSString*)transferUID;

- (void)abortAllTransferRequests;

- (void)receiveTransferRequestWithInfoDict:(NSDictionary*)infoDict onConnection:(TPNetworkConnection*)connection isClient:(BOOL)isClient;

- (void)transferDidStart:(TPTransfer*)transfer;
- (void)transfer:(TPTransfer*)transfer didProgress:(float)progress;
- (void)transferDidComplete:(TPTransfer*)transfer;
- (void)transferDidCancel:(TPTransfer*)transfer;

@end

@interface NSObject (TPTransfersManager_delegate)

- (void)transfersManager:(TPTransfersManager*)transfersManager beginNewTransfer:(TPTransfer*)transfer;
- (void)transfersManager:(TPTransfersManager*)transfersManager transfer:(TPTransfer*)transfer didProgress:(float)progress;
- (void)transfersManager:(TPTransfersManager*)transfersManager completeTransfer:(TPTransfer*)transfer;
- (void)transfersManager:(TPTransfersManager*)transfersManager cancelTransfer:(TPTransfer*)transfer;

@end