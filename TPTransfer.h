//
//  TPTransfer.h
//  teleport
//
//  Created by JuL on 13/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPTransfersManager.h"

typedef NS_ENUM(NSInteger, TPTransferPriority) {
	TPTransferHighPriority,
	TPTransferMediumPriority,
	TPTransferLowPriority
} ;

extern NSString * TPTransferUIDKey;
extern NSString * TPTransferTypeKey;
extern NSString * TPTransferDataLengthKey;
extern NSString * TPTransferPortKey;

@class TPTCPSecureSocket, TPRemoteHost/*, TPNetworkConnection*/;

@interface TPTransfer : NSObject
{
	TPTCPSecureSocket * _listenSocket;
	TPTCPSecureSocket * _socket;
//	TPNetworkConnection * _connection;
	NSLock * _lock;
	
	NSString * _uid;
	NSMutableData * _data;
	TPDataLength _totalDataLength;
	TPDataLength _receivedDataLength;
	
	
//	id _delegate;
	TPTransfersManager * _manager;
}

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, copy) NSString *uid;
@property (nonatomic, readonly) TPTransferPriority priority;

//- (void)setDelegate:(id)delegate;
//- (id)delegate;

- (void)setManager:(TPTransfersManager*)manager;

@property (nonatomic, getter=isIncoming, readonly) BOOL incoming;
@property (nonatomic, readonly) BOOL hasFeedback;
@property (nonatomic, readonly, copy) NSString *completionMessage;
@property (nonatomic, readonly, copy) NSString *errorMessage;

//- (void)setConnection:(TPNetworkConnection*)connection;

@end

@interface TPOutgoingTransfer : TPTransfer
{
}

+ (TPOutgoingTransfer*)transfer;

- (void)_beginTransfer;

@property (nonatomic, readonly) BOOL shouldBeEncrypted;

@property (nonatomic, readonly, copy) NSData *dataToTransfer;
@property (nonatomic, readonly) TPDataLength totalDataLength;
@property (nonatomic, readonly, copy) NSDictionary *infoDict;

@property (nonatomic, readonly) BOOL prepareToSendData;
- (void)setSocket:(TPTCPSocket*)socket;

@end

@interface TPIncomingTransfer : TPTransfer
{
	BOOL _shouldEncrypt;
}

+ (TPIncomingTransfer*)transferOfType:(NSString*)type withUID:(NSString*)uid;

@property (nonatomic, readonly) BOOL requireTrustedHost;

- (void)_stopListening;

- (BOOL)prepareToReceiveDataWithInfoDict:(NSDictionary*)infoDict fromHost:(TPRemoteHost*)host onPort:(int*)port delegate:(id)delegate;

@end
