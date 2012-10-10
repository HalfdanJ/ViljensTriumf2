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

#import "ChromaFilter.h"
#import "DeinterlaceFilter.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    CIImage * cameras[3];
    float chromaMinSet, chromaMaxSet;
}

@property (unsafe_unretained) IBOutlet NSWindow *mainOutputWindow;
@property (assign) IBOutlet NSWindow *window;
@property (strong) BlackMagicController * blackMagicController;
@property (weak) IBOutlet CoreImageViewer *preview1;
@property (weak) IBOutlet CoreImageViewer *preview2;
@property (weak) IBOutlet CoreImageViewer *preview3;
@property (weak) IBOutlet CoreImageViewer *mainOutput;

@property (strong) DeinterlaceFilter * deinterlaceFilter;
@property (strong) CIFilter * colorControlsFilter;
@property (strong) CIFilter * gammaAdjustFilter;
@property (strong) CIFilter * toneCurveFilter;
@property (strong) ChromaFilter * chromaFilter;
@property (strong) CIFilter * dissolveFilter;
@property (strong) CIFilter * sourceOverFilter;
@property (strong) CIFilter * constantColorFilter;

@property (readwrite) int outSelector;

@property (readwrite) float master;

-(void) newFrame:(DecklinkCallback*)callback;

@end
