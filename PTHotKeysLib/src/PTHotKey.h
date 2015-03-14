//
//  PTHotKey.h
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PTKeyCombo.h"

@interface PTHotKey : NSObject
{
	int				mID;
	NSString*		mIdentifier;
	NSString*		mName;
	PTKeyCombo*		mKeyCombo;
	id				mTarget;
	SEL				mAction;
}

- (instancetype)initWithIdentifier: (id)identifier keyCombo: (PTKeyCombo*)combo NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@property (nonatomic, strong) id identifier;

@property (nonatomic, readonly) int ID;

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) PTKeyCombo *keyCombo;

@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic) SEL action;

- (void)invoke;

@end
