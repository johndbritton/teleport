//
//  TPNetworkConnection.h
//  teleport
//
//  Created by JuL on Mon Dec 29 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TPHost.h"

@class TPMessage, TPRemoteHost;
@class TPTransfersManager, TPTransfer;

@interface TPNetworkConnection : NSObject
{
	TPTCPSocket * _socket;
	
	NSMutableArray * _pendingMessages;
	TPRemoteHost * _connectedHost;
	TPHostCapability _capabilities;
	
	NSMutableData * _msgBuffer;
	
	TPTransfersManager * _transfersManager;

	id _delegate;
}

- (instancetype) initWithSocket:(TPTCPSocket*)socket NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, strong) TPTCPSocket *socket;

@property (nonatomic, readonly, strong) NSString *networkInterfaceName;

@property (nonatomic, readonly, strong) TPTransfersManager *transfersManager;

@property (nonatomic, strong) TPRemoteHost *connectedHost;

- (BOOL)isValidForHost:(TPRemoteHost*)host;

@property (nonatomic, readonly) TPHostCapability localHostCapabilities;

@property (nonatomic, unsafe_unretained) id delegate;

- (void)disconnect;
- (BOOL)sendMessage:(TPMessage*)message;

@end

@interface NSObject (TPNetworkConnection_delegate)

- (void)connectionDisconnected:(TPNetworkConnection*)connection;
- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message;

@end
