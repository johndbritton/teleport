//
//  TPVersionTextField.h
//  teleport
//
//  Created by JuL on Sat Feb 28 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TPVersionTextField : NSTextField
{
	NSArray * _versions;
	int _currentVersionIndex;
}

- (void)setVersions:(NSArray*)inVersions;
- (void)mouseDown:(NSEvent*)event;
- (void)changeVersion;

@end
