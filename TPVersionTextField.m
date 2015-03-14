//
//  TPVersionTextField.m
//  teleport
//
//  Created by JuL on Sat Feb 28 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPVersionTextField.h"


@implementation TPVersionTextField

- (void)_commonInit
{
	_currentVersionIndex = -1;
	_versions = nil;
}

- (instancetype) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];

	[self _commonInit];
	
	return self;
}

- (instancetype) initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];
	
	[self _commonInit];
	
	return self;
}


- (void)setVersions:(NSArray*)versions
{
	if(versions != _versions) {
		_versions = versions;
		[self changeVersion];
	}
}

- (void)mouseDown:(NSEvent*)event
{
	[self changeVersion];
}

- (void)changeVersion
{
	if(_versions == nil || [_versions count] == 0)
		return;
	
	if(++_currentVersionIndex == [_versions count])
		_currentVersionIndex = 0;
	
	NSString * version = _versions[_currentVersionIndex];
	
	[self setStringValue:version];
}

@end
