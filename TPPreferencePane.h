//
//  TPPreferencePane.h
//  Teleport
//
//  Created by JuL on Mon Dec 08 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <AppKit/AppKit.h>

@class TPLayoutView, TPLocalHost, TPRemoteHost;
@class TPPreferencesManager;

@interface TPPreferencePane : NSWindowController
{
	NSView * view;
	IBOutlet TPLayoutView * layoutView;
	IBOutlet id allowControlCheckbox;
	IBOutlet id statusCheckbox;
	IBOutlet id aboutWindow;
	IBOutlet id versionTextField;
	IBOutlet id logoView;
	IBOutlet id trustedHostsWindow;
	IBOutlet id trustedHostsTableView;
	
	IBOutlet id showCertificateButton;
	IBOutlet id chooseCertificateButton;
	
	NSWindow * _alertPanel;
	NSArray * _trustedHosts;
	BOOL _active;
}

+ (instancetype)preferencePane;

/* For bindings */
@property (nonatomic, readonly, strong) TPPreferencesManager *prefs;
@property (nonatomic, readonly, strong) TPLocalHost *localHost;

- (IBAction)showAboutSheet:(id)sender;
- (void)closeAboutSheet;

/* Add other */
- (IBAction)addOther:(id)sender;
- (IBAction)closeAddOther:(id)sender;
- (IBAction)confirmAddOther:(id)sender;

/* Trusted hosts */
- (IBAction)showTrustedHosts:(id)sender;
- (IBAction)closeTrustedHosts:(id)sender;
- (IBAction)deleteTrustedHost:(id)sender;
- (void)reloadTrustedHosts;

/* Certificate actions */
- (IBAction)showCertificateViewer:(id)sender;
- (IBAction)showCertificateChooser:(id)sender;

/* Other actions */
- (IBAction)checkVersion:(id)sender;

@end
