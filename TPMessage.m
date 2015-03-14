//
//  TPMessage.m
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPMessage.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"
#import "TPUtils.h"

const unsigned TPMessageHeaderLength = sizeof(TPMsgType)+sizeof(TPDataLength);

@interface TPMessage (Private)

- (instancetype) initWithType:(TPMsgType)type;
- (instancetype) initWithType:(TPMsgType)type andData:(NSData*)data;
- (instancetype) initWithType:(TPMsgType)type andString:(NSString*)string;
- (instancetype) initWithType:(TPMsgType)type andInfoDict:(NSDictionary*)infoDict;

@end

@implementation TPMessage

- (instancetype) init
{
	self = [super init];
	
	_additionalData = nil;
	
	return self;
}

- (instancetype) initWithRawData:(NSData*)rawData
{
	self = [self init];
	
	int pos = 0;
	
	@try {
		/* Read message type */
		[rawData _readBytes:&_msgType withSize:sizeof(TPMsgType) atPos:&pos];
		
		/* Read data length */
		[rawData _readBytes:&_dataLength withSize:sizeof(TPDataLength) atPos:&pos];
		if([self dataLength] > 0) {
			TPDataLength dataLength = [self dataLength];
			if(dataLength > [rawData length]-pos) { // not enough data!
				return nil;
			}
			else
				_additionalData = [[rawData subdataWithRange:NSMakeRange(pos, dataLength)] copy];
		}
		else
			_additionalData = nil;
	}
	@catch(NSException * exception) {
		return nil;
	}
		
	return self;
}


- (NSData*)rawData
{
	NSMutableData * rawData = [[NSMutableData alloc] init];

	/* Write message type */
	[rawData appendData:[NSData dataWithBytes:&_msgType length:sizeof(TPMsgType)]];
	
	/* Optionally write data */
	if(_additionalData != nil) {
		_dataLength = NSSwapHostLongLongToBig([_additionalData length]);
		[rawData appendData:[NSData dataWithBytes:&_dataLength length:sizeof(TPDataLength)]];
		[rawData appendData:_additionalData];
	}
	else {
		_dataLength = NSSwapHostLongLongToBig(0);
		[rawData appendData:[NSData dataWithBytes:&_dataLength length:sizeof(TPDataLength)]];
	}
		
	return rawData;
}


#pragma mark -
#pragma mark Protocol messages

- (instancetype) initWithType:(TPMsgType)type
{
	self = [self init];
	_msgType = NSSwapHostIntToBig(type);
	return self;
}

- (instancetype) initWithType:(TPMsgType)type andData:(NSData*)data
{
	self = [self initWithType:type];
	
	_additionalData = data;
	
	return self;
}

- (instancetype) initWithType:(TPMsgType)type andString:(NSString*)string
{
	self = [self initWithType:type];
	
	_additionalData = [string dataUsingEncoding:NSUTF8StringEncoding];
	
	return self;
}

- (instancetype) initWithType:(TPMsgType)type andInfoDict:(NSDictionary*)infoDict
{
	self = [self initWithType:type];
	
	_additionalData = [NSArchiver archivedDataWithRootObject:infoDict];
	
	return self;
}

+ (instancetype) messageWithType:(TPMsgType)type
{
	TPMessage * message = [[TPMessage alloc] initWithType:type];
	return message;
}

+ (instancetype) messageWithType:(TPMsgType)type andData:(NSData*)data
{
	TPMessage * message = [[TPMessage alloc] initWithType:type andData:data];
	return message;
}

+ (instancetype) messageWithType:(TPMsgType)type andString:(NSString*)string
{
	TPMessage * message = [[TPMessage alloc] initWithType:type andString:string];
	return message;
}

+ (instancetype) messageWithType:(TPMsgType)type andInfoDict:(NSDictionary*)infoDict
{
	TPMessage * message = [[TPMessage alloc] initWithType:type andInfoDict:infoDict];
	return message;
}


#pragma mark -
#pragma mark Accessors

- (TPMsgType)msgType
{
	return NSSwapBigIntToHost(_msgType);
}

- (TPDataLength)msgLength
{
	return [self dataLength] + TPMessageHeaderLength;
}

- (TPDataLength)dataLength
{
	return NSSwapBigLongLongToHost(_dataLength);
}
	
- (NSData*)data
{
	return _additionalData;
}

- (NSString*)string
{
	return [[NSString alloc] initWithData:_additionalData encoding:NSUTF8StringEncoding];
}

- (NSDictionary*)infoDict
{
	return (NSDictionary*)[NSUnarchiver unarchiveObjectWithData:_additionalData];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@ type=%ld data length=%lu", [super description], _msgType, (unsigned long)[_additionalData length]];
}

@end
