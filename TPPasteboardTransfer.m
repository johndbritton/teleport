//
//  TPPasteboardTransfer.m
//  teleport
//
//  Created by JuL on 14/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import "TPTransfer_Private.h"
#import "TPPasteboardTransfer.h"
#import "TPPreferencesManager.h"

static NSString * TPPasteboardTransferNameKey = @"TPPasteboardTransferName";
static NSString * TPPasteboardTransferChangeCountKey = @"TPPasteboardTransferChangeCount";

static inline BOOL TPTypeNeedsSwapping(NSString * type)
{
	if(CFByteOrderGetCurrent() == CFByteOrderBigEndian) {
		return NO;
	}
	else {
		return [type isEqualToString:@"public.utf16-plain-text"] || [type isEqualToString:@"CorePasteboardFlavorType 0x75747874"]; // utxt
	}
}

static inline BOOL TPTypeNeedsIgnoring(NSString * type)
{
	return [type isEqualToString:@"com.apple.txn.text-multimedia-data"] || [type isEqualToString:@"CorePasteboardFlavorType 0x7478746E"]; // txtn
}

@implementation TPOutgoingPasteboardTransfer

- (instancetype) init
{
	self = [super init];
	
	_pasteboardName	= NSGeneralPboard;
	
	return self;
}


- (NSString*)type
{
	return @"TPIncomingPasteboardTransfer";
}

- (void)setPasteboardName:(NSString*)pasteboardName
{
	if(pasteboardName != _pasteboardName) {
		_pasteboardName = pasteboardName;
	}
}

- (void)setMaxSize:(unsigned long long)maxSize
{
	_maxSize = maxSize;
}

- (BOOL)shouldBeEncrypted
{
	return YES;
}

- (BOOL)requireTrustedHost
{
	return YES;
}

- (TPTransferPriority)priority
{
	return TPTransferHighPriority;
}

- (BOOL)hasFeedback
{
	return YES;
}

- (NSString*)completionMessage
{
	NSString * sizeString = [NSString sizeStringForSize:[self totalDataLength]];
	return [NSString stringWithFormat:NSLocalizedString(@"Pasteboard sent (%@)", nil), sizeString];
}

- (NSString*)errorMessage
{
	return NSLocalizedString(@"Pasteboard not sent", nil);
}

- (NSDictionary*)infoDict
{
	NSMutableDictionary * infoDict = [[NSMutableDictionary alloc] initWithDictionary:[super infoDict]];
	
	[infoDict addEntriesFromDictionary:@{TPPasteboardTransferNameKey: _pasteboardName,
		TPPasteboardTransferChangeCountKey: [NSNumber numberWithInt:[[NSPasteboard pasteboardWithName:_pasteboardName] changeCount]]}];
	
	return infoDict;
}

- (NSData*)dataToTransfer
{
	NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
	NSPasteboard * pasteboard = [NSPasteboard pasteboardWithName:_pasteboardName];
	NSArray * pasteboardTypes = [pasteboard types];
	NSEnumerator * typeEnum = [pasteboardTypes objectEnumerator];
	NSString * type;
	
	unsigned long long pasteboardSize = 0;
	while((type = [typeEnum nextObject])) {
		if(TPTypeNeedsIgnoring(type)) {
			DebugLog(@"Ignoring type %@", type);
			continue;
		}
		
		NSData * data = [pasteboard dataForType:type];
		if(data != nil) {
			if(TPTypeNeedsSwapping(type)) {
				DebugLog(@"Swapping type %@ to BE", type);
				CFStringRef string = CFStringCreateFromExternalRepresentation(NULL, (CFDataRef)data, kCFStringEncodingUTF16LE);
				if(string != NULL) {
					CFDataRef newData = CFStringCreateExternalRepresentation(NULL, (CFStringRef)string, kCFStringEncodingUTF16BE, '?');
					CFRelease(string);
					if(newData != NULL) {
						data = (NSData*)CFBridgingRelease(newData);
					}
				}
			}
			
			if([data bytes] != NULL) { // work-around Tiger bug
				dictionary[type] = data;
				pasteboardSize += [data length];
			}
		}
	}
	
	if(pasteboardSize == 0) {
		return nil;
	}
	else if(_maxSize > 0 && pasteboardSize > _maxSize) {
		DebugLog(@"maxSize=%lld pasteboardSize=%lld", _maxSize, pasteboardSize);
		return nil;
	}
	
	NSData * dataToTransfer = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
	
	return dataToTransfer;
}

- (CFIndex)generationCount
{
//	CFPasteboardRef pasteboardRef = CFPasteboardCreate(NULL, (CFStringRef)_pasteboardName);
//	CFPasteboardGetGenerationCount(pasteboardRef);
	return 0;
}

@end

@implementation TPIncomingPasteboardTransfer


- (TPTransferPriority)priority
{
	return TPTransferHighPriority;
}

- (BOOL)hasFeedback
{
	return YES;
}

- (NSString*)completionMessage
{
	NSString * sizeString = [NSString sizeStringForSize:_totalDataLength];
	return [NSString stringWithFormat:NSLocalizedString(@"Pasteboard received (%@)", nil), sizeString];
}

- (NSString*)errorMessage
{
	return NSLocalizedString(@"Pasteboard failed to receive", nil);
}

- (BOOL)prepareToReceiveDataWithInfoDict:(NSDictionary*)infoDict fromHost:(TPRemoteHost*)host onPort:(int*)port delegate:(id)delegate
{
	_pasteboardName = [infoDict[TPPasteboardTransferNameKey] copy];
	//	int changeCount = [[infoDict objectForKey:TPPasteboardTransferChangeCountKey] intValue];
	//	
	//	NSPasteboard * pasteboard = [NSPasteboard pasteboardWithName:_pasteboardName];
	
	return [super prepareToReceiveDataWithInfoDict:infoDict fromHost:host onPort:port delegate:delegate];
}

- (void)_receiverDataTransferCompleted
{
	NSMutableDictionary * dictionary = [NSKeyedUnarchiver unarchiveObjectWithData:_data];
	NSPasteboard * pasteboard = [NSPasteboard pasteboardWithName:_pasteboardName];
	NSArray * pasteboardTypes = [dictionary allKeys];
	NSEnumerator * typeEnum = [pasteboardTypes objectEnumerator];
	NSString * type;
	
	[pasteboard declareTypes:pasteboardTypes owner:nil];
	
	while((type = [typeEnum nextObject])) {
		NSData * data = dictionary[type];
		
		if(TPTypeNeedsSwapping(type)) {
			DebugLog(@"Swapping type %@ from BE", type);
			CFStringRef string = CFStringCreateFromExternalRepresentation(NULL, (CFDataRef)data, kCFStringEncodingUTF16BE);
			if(string != NULL) {
				CFDataRef newData = CFStringCreateExternalRepresentation(NULL, (CFStringRef)string, kCFStringEncodingUTF16LE, '?');
				CFRelease(string);
				if(newData != NULL) {
					data = (NSData*)CFBridgingRelease(newData);
				}
			}
		}
		
		if([data bytes] != NULL) {
			[pasteboard setData:data forType:type];
		}
	}
	
	[super _receiverDataTransferCompleted];
}

@end

