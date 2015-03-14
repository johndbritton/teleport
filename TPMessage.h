//
//  TPMessage.h
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const unsigned TPMessageHeaderLength;

@interface TPMessage : NSObject
{
	TPDataLength _dataLength;
	TPMsgType _msgType;

	NSData * _additionalData;
}

- (instancetype) initWithRawData:(NSData*)rawData;

/* Protocol messages */
+ (instancetype) messageWithType:(TPMsgType)type;
+ (instancetype) messageWithType:(TPMsgType)type andData:(NSData*)data;
+ (instancetype) messageWithType:(TPMsgType)type andString:(NSString*)string;
+ (instancetype) messageWithType:(TPMsgType)type andInfoDict:(NSDictionary*)infoDict;

/* Accessors */
@property (nonatomic, readonly, copy) NSData *rawData;

@property (nonatomic, readonly) TPMsgType msgType;
@property (nonatomic, readonly) TPDataLength msgLength;
@property (nonatomic, readonly) TPDataLength dataLength;

@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly, copy) NSString *string;
@property (nonatomic, readonly, copy) NSDictionary *infoDict;

@end
