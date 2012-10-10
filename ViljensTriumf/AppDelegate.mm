//
//  AppDelegate.m
//  ViljensTriumf
//
//  Created by Jonas on 10/10/12.
//  Copyright (c) 2012 Jonas. All rights reserved.
//

#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.blackMagicController = [[BlackMagicController alloc] init];
    [self.blackMagicController initDecklink];
    [self.blackMagicController callbacks:0]->delegate = self;
    [self.blackMagicController callbacks:1]->delegate = self;
    [self.blackMagicController callbacks:2]->delegate = self;
    
    
    if([[NSScreen screens] count] > 1){
        NSScreen * screen = [NSScreen screens][1];
        NSRect screenRect = [screen frame];
        [self.mainOutputWindow setLevel: CGShieldingWindowLevel()];
        [self.mainOutputWindow setFrame:screenRect display:YES];
    }
    
}

-(CIImage*) createCIImageFromCallback:(DecklinkCallback*)callback{
    int w = callback->w;
    int h = callback->h;
    unsigned char * bytes = callback->bytes;
    
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    
    CVPixelBufferRef buffer = NULL;
    
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, w, h, k32BGRAPixelFormat, bytes, 4*w, (CVPixelBufferReleaseBytesCallback )nil, (void*)nil, (__bridge CFDictionaryRef)d, &buffer);
    
    return [CIImage imageWithCVImageBuffer:buffer];
}

-(void) newFrame:(DecklinkCallback*)callback{
    CIImage * image  = [self createCIImageFromCallback:callback];
    
    int num = -1;
    if(callback == [self.blackMagicController callbacks:0]){
        num = 0;
    }
    else if(callback == [self.blackMagicController callbacks:1]){
        num = 1;
    }
    else if(callback == [self.blackMagicController callbacks:2]){
        num = 2;
    }
    
    CoreImageViewer * preview = nil;
    switch (num) {
        case 0:
            preview = self.preview1;
            break;
        case 1:
            preview = self.preview2;
            break;
        case 2:
            preview = self.preview3;
            break;
            
        default:
            break;
    }
    
    
    preview.ciImage = image;
    [preview setNeedsDisplay:YES];

    if(num == 0){
    self.mainOutput.ciImage = image;
    [self.mainOutput setNeedsDisplay:YES];
    }


}

@end
