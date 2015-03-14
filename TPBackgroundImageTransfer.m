//
//  TPBackgroundImageTransfer.m
//  teleport
//
//  Created by JuL on 10/05/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import "TPBackgroundImageTransfer.h"
#import "TPTransfer_Private.h"

#import "TPHostsManager.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"

NSString * TPBackgroundImageTransferIdentifierKey = @"TPBackgroundImageTransferIdentifier";
NSString * TPBackgroundImageTransferDataKey = @"TPBackgroundImageTransferData";

#define ENABLE_BACKGROUND_IMAGE_TRANSFER 1

@implementation TPOutgoingBackgroundImageTransfer

- (NSString*)type
{
	return @"TPIncomingBackgroundImageTransfer";
}

- (NSData*)dataToTransfer
{
#if ENABLE_BACKGROUND_IMAGE_TRANSFER
	NSDictionary * dict = @{TPBackgroundImageTransferIdentifierKey: [[TPLocalHost localHost] identifier],
		TPBackgroundImageTransferDataKey: [[TPLocalHost localHost] backgroundImageData]};
	return [NSKeyedArchiver archivedDataWithRootObject:dict];
#else
	return nil;
#endif
}

@end

@implementation TPIncomingBackgroundImageTransfer

- (void)_receiverDataTransferCompleted
{
	DebugLog(@"_receiverDataTransferCompleted %@ on thread %@", self, [NSThread currentThread]);
	
	NSMutableDictionary * dict = nil;
	
	@try {
		dict = [NSKeyedUnarchiver unarchiveObjectWithData:_data];
	}
	@catch(NSException *e) {
		DebugLog(@"exception when unarchiving dictionary: %@", e);
	}
	
	if(dict != nil) {
		NSString * identifier = dict[TPBackgroundImageTransferIdentifierKey];
		NSData * backgroundImageData = dict[TPBackgroundImageTransferDataKey];
		TPRemoteHost * host = [[TPHostsManager defaultManager] hostWithIdentifier:identifier];
		
		if(host != nil && backgroundImageData != nil) {
			NSImage * backgroundImage = [[NSImage alloc] initWithData:backgroundImageData];
			[host setBackgroundImage:backgroundImage];
		}
	}
	
	[super _receiverDataTransferCompleted];
}

@end
