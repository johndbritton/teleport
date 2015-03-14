//
//  TPUtils.h
//  teleport
//
//  Created by Julien Robert on 11/10/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSData (TPUtils)

- (void)_readBytes:(void*)bytes withSize:(unsigned int)size atPos:(int*)pos;

+ (NSData*)dataWithRect:(NSRect)rect;
@property (nonatomic, readonly) NSRect rectValue;

+ (NSData*)dataWithPoint:(NSPoint)point;
@property (nonatomic, readonly) NSPoint pointValue;

+ (NSData*)dataWithSize:(NSSize)size;
@property (nonatomic, readonly) NSSize sizeValue;

+ (NSData*)dataWithString:(NSString*)string;
@property (nonatomic, readonly, copy) NSString *stringValue;

+ (NSData*)dataWithInt:(int)i;
@property (nonatomic, readonly) int intValue;

+ (NSData*)dataWithBool:(BOOL)b;
@property (nonatomic, readonly) BOOL boolValue;

@end

@interface NSString (TPAdditions)

+ (NSString*)sizeStringForSize:(TPDataLength)size;

+ (NSString*)stringWithInt:(int)i;
+ (NSString*)stringWithBool:(BOOL)b;
@property (nonatomic, readonly, copy) NSString *stringValue;
@property (nonatomic, readonly) BOOL boolValue;

@end

@interface NSWorkspace (TPAdditions)

- (NSDictionary*)typeDictForPath:(NSString*)path;

@property (nonatomic, readonly, copy) NSString *computerIdentifier;

@end


@interface NSFileManager (TPAdditions)

- (BOOL)isTotalSizeOfItemAtPath:(NSString*)path smallerThan:(unsigned long long)maxSize;

@end
