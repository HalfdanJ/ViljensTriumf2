//
//  AppDelegate.h
//  ViljensTriumf
//
//  Created by Jonas on 10/10/12.
//  Copyright (c) 2012 Jonas. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BlackMagicController.h"
#import "CoreImageViewer.h"

#import "DecklinkCallback.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) IBOutlet NSWindow *mainOutputWindow;
@property (assign) IBOutlet NSWindow *window;
@property (strong) BlackMagicController * blackMagicController;
@property (weak) IBOutlet CoreImageViewer *preview1;
@property (weak) IBOutlet CoreImageViewer *preview2;
@property (weak) IBOutlet CoreImageViewer *preview3;
@property (weak) IBOutlet CoreImageViewer *mainOutput;

-(void) newFrame:(DecklinkCallback*)callback;

@end
