//
//  TPPasteboardTransfer.h
//  teleport
//
//  Created by JuL on 14/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPTransfer.h"

@interface TPOutgoingPasteboardTransfer : TPOutgoingTransfer
{
	NSString * _pasteboardName;
	unsigned long long _maxSize;
}

- (void)setPasteboardName:(NSString*)pasteboardName;
- (void)setMaxSize:(unsigned long long)maxSize;

@property (nonatomic, readonly) CFIndex generationCount;

@end

@interface TPIncomingPasteboardTransfer : TPIncomingTransfer
{
	NSString * _pasteboardName;
}

@end
