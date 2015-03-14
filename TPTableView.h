//
//  TPTableView.h
//  teleport
//
//  Created by JuL on 12/05/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TPTableView : NSTableView

@end

@interface NSObject (TPTableViewDelegate)

- (BOOL)tableView:(NSTableView*)tableView handleKeyDown:(NSEvent*)event;

@end
