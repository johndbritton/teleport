//
//  TPKeyComboView.h
//  teleport
//
//  Created by Julien Robert on 08/04/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PTKeyCombo.h"

@interface TPKeyComboView : NSView
{
	id _delegate;
	PTKeyCombo * _keyCombo;
}

@property (nonatomic, unsafe_unretained) id delegate;

@property (nonatomic, copy) PTKeyCombo *keyCombo;

@end

@interface NSObject (TPKeyComboTextFieldDelegate)

- (void)keyComboDidChange:(PTKeyCombo*)keyCombo;

@end
