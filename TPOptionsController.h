//
//  TPOptionsController.h
//  teleport
//
//  Created by Julien Robert on 02/04/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TPRemoteHost, TPLayoutView, TPKeyComboView, TPLayoutScreenView, TPLayoutOptionsProxy;

@interface TPOptionsController : NSResponder
{	
	IBOutlet NSObjectController * hostController;
	IBOutlet NSTextField * titleTextField;
	IBOutlet NSView * hostOptionsView;
	IBOutlet TPLayoutView * layoutView;
	IBOutlet TPKeyComboView * keyComboView;
	IBOutlet NSButton * restoreSaveDefaultsButton;
	
	TPRemoteHost * _host;
	TPLayoutOptionsProxy * _optionsProxy;
	TPLayoutScreenView * _currentScreenView;
	NSRect _currentScreenFrame;
}

+ (TPOptionsController*)controller;

- (void)showOptionsForHost:(TPRemoteHost*)host sharedScreenIndex:(unsigned)screenIndex fromRect:(NSRect)frame;
- (IBAction)restoreToDefaults:(id)sender;
- (IBAction)useAsDefaults:(id)sender;
- (IBAction)closeOptions:(id)sender;

@property (nonatomic, readonly, strong) TPRemoteHost *host;
@property (nonatomic, readonly, strong) id hostOptions;

@end
