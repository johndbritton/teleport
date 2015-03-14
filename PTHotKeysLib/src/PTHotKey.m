//
//  PTHotKey.m
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTHotKey.h"

#import "PTHotKeyCenter.h"
#import "PTKeyCombo.h"

static int HotKeyID = 0;

@implementation PTHotKey

- (instancetype)init
{
	return [self initWithIdentifier: nil keyCombo: nil];
}


- (instancetype)initWithIdentifier: (id)identifier keyCombo: (PTKeyCombo*)combo
{
	self = [super init];
	
	if( self )
	{
		[self setIdentifier: identifier];
		[self setKeyCombo: combo];
		mID = ++HotKeyID;
	}
	
	return self;
}


- (NSString*)description
{
	return [NSString stringWithFormat: @"<%@: %@, %@>", NSStringFromClass( [self class] ), [self identifier], [self keyCombo]];
}

#pragma mark -

- (void)setIdentifier: (id)ident
{
	mIdentifier = ident;
}

- (id)identifier
{
	return mIdentifier;
}

- (int)ID
{
	return mID;
}

- (void)setKeyCombo: (PTKeyCombo*)combo
{
	if( combo == nil )
		combo = [PTKeyCombo clearKeyCombo];	

	mKeyCombo = combo;
}

- (PTKeyCombo*)keyCombo
{
	return mKeyCombo;
}

- (void)setName: (NSString*)name
{
	mName = name;
}

- (NSString*)name
{
	return mName;
}

- (void)setTarget: (id)target
{
	mTarget = target;
}

- (id)target
{
	return mTarget;
}

- (void)setAction: (SEL)action
{
	mAction = action;
}

- (SEL)action
{
	return mAction;
}

- (void)invoke
{
	[mTarget performSelector: mAction withObject: self];
}

@end
