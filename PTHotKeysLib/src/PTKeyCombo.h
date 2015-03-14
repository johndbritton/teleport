//
//  PTKeyCombo.h
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __PROTEIN__
#else
#define _PTLocalizedString NSLocalizedString
#endif

@interface PTKeyCombo : NSObject <NSCopying>
{
	int	mKeyCode;
	int	mModifiers;
}

+ (id)clearKeyCombo;
+ (instancetype)keyComboWithKeyCode: (int)keyCode modifiers: (int)modifiers;
- (instancetype)initWithKeyCode: (int)keyCode modifiers: (int)modifiers NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithPlistRepresentation: (id)plist;
@property (nonatomic, readonly, strong) id plistRepresentation;

- (BOOL)isEqual: (PTKeyCombo*)combo;

@property (nonatomic, readonly) int keyCode;
@property (nonatomic, readonly) int modifiers;

@property (nonatomic, getter=isClearCombo, readonly) BOOL clearCombo;
@property (nonatomic, getter=isValidHotKeyCombo, readonly) BOOL validHotKeyCombo;

@end

@interface PTKeyCombo (UserDisplayAdditions)

@property (nonatomic, readonly, copy) NSString *description;

@end
