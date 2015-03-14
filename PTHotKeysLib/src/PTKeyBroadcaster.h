//
//  PTKeyBroadcaster.h
//  Protein
//
//  Created by Quentin Carnicelli on Sun Aug 03 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <AppKit/AppKit.h>
#if __PROTEIN__
#import "ProteinDefines.h"
#else
#define PROTEIN_EXPORT __private_extern__
#endif

@interface PTKeyBroadcaster : NSButton
{
}

+ (long)cocoaModifiersAsCarbonModifiers: (long)cocoaModifiers;

@end

NSString* PTKeyBroadcasterKeyEvent; //keys: keyCombo as PTKeyCombo
