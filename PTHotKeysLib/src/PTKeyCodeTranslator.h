//
//  PTKeyCodeTranslator.h
//  Chercher
//
//  Created by Finlay Dobbie on Sat Oct 11 2003.
//  Copyright (c) 2003 Cliché Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>

@interface PTKeyCodeTranslator : NSObject
{
#if LEGACY_BUILD
    KeyboardLayoutRef	keyboardLayout;
    UCKeyboardLayout	*uchrData;
    void		*KCHRData;
    SInt32		keyLayoutKind;
    UInt32		keyTranslateState;
    UInt32		deadKeyState;
#else
	TISInputSourceRef keyboardLayout;
    const UCKeyboardLayout *uchrData;
	
    UInt32              keyTranslateState;
    UInt32              deadKeyState;
#endif
}

+ (id)currentTranslator;

- (NSString *)translateKeyCode:(short)keyCode;

@end
