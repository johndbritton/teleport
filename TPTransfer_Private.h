/*
 *  TPTransfer_Private.h
 *  teleport
 *
 *  Created by JuL on 19/04/06.
 *  Copyright 2006 abyssoft. All rights reserved.
 *
 */

#import "TPTransfer.h"

@interface TPTransfer (Private)

- (void)_sendData;

- (void)_transferDidProgress:(float)progress;
- (void)_transferDone;

- (void)_senderDataTransferCompleted;
- (void)_senderDataTransferFailed;
- (void)_senderDataTransferAborted;

- (void)_receiverDataTransferCompleted;
- (void)_receiverDataTransferFailed;
- (void)_receiverDataTransferAborted;

@end
