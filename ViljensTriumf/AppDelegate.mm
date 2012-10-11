//
//  AppDelegate.m
//  ViljensTriumf
//
//  Created by Jonas on 10/10/12.
//  Copyright (c) 2012 Jonas. All rights reserved.
//

#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import "BeamSync.h"

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
    
    [BeamSync disable];
    
    //
    //Init filters
    //
    
    self.colorControlsFilter = [CIFilter filterWithName:@"CIColorControls"] ;
    [self.colorControlsFilter setDefaults];
    
    self.gammaAdjustFilter = [CIFilter filterWithName:@"CIGammaAdjust"];
    [self.gammaAdjustFilter setDefaults];
    
    self.toneCurveFilter = [CIFilter filterWithName:@"CIToneCurve"];
    [self.toneCurveFilter setDefaults];

    self.dissolveFilter = [CIFilter filterWithName:@"CIDissolveTransition"];
    [self.dissolveFilter setDefaults];
    
    self.constantColorFilter = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    self.sourceOverFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];

    self.deinterlaceFilter = [[DeinterlaceFilter alloc] init];
    [self.deinterlaceFilter setDefaults];
    
    self.chromaFilter = [[ChromaFilter alloc] init];
    
    self.master = 1.0;
    
//    [NSLayoutConstraint constraintWithItem:self.preview1 attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.preview1 attribute:NSLayoutAttributeHeight multiplier:4.0/3.0 constant:1.0];
//    self.preview1
    
    
    
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSKeyDownMask) handler:^(NSEvent *incomingEvent) {
		NSLog(@"Events: %@",incomingEvent);
		
        //	if ([NSEvent modifierFlags] & NSAlternateKeyMask) {
        /*if( == 83){
         fadeTo = 0;
         fade = 0;
         } else {
         selectedCam = 0;
         }
         }*/
        switch ([incomingEvent keyCode]) {
            case 82:
                self.outSelector = 0;
                
                break;
                
            case 83:
                self.outSelector  = 1;
                /*   serial.writeByte('1');
                 serial.writeByte('*');
                 serial.writeByte('4');
                 serial.writeByte('!');*/
                break;
            case 84:
                self.outSelector  = 2;
                /*            serial.writeByte('2');
                 serial.writeByte('*');
                 serial.writeByte('4');
                 serial.writeByte('!');*/
                break;
            case 85:
                self.outSelector  = 3;
                /*            serial.writeByte('3');
                 serial.writeByte('*');
                 serial.writeByte('4');
                 serial.writeByte('!');*/
                break;
                /*  case 86:
                 if(recordMovie){
                 [self stopRecording];
                 } else {
                 [self startRecording];
                 }
                 break;*/
            /*case 86:
                recordMovie = false;
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Play movie, time %lli",[mMovie duration].timeValue);
                    [mMovie gotoBeginning];
                    [mMovie play];
                });
                outSelector = 4;
                break;
                */
            default:
                return incomingEvent;
                
                break;
        }
        return (NSEvent*)nil;
    }];

    
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    [BeamSync enable];
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
    
    if(num == 0  && [[NSUserDefaults standardUserDefaults] boolForKey:@"chromaKey"]){
        image = [self chromaKey:image backgroundImage:cameras[1]];
    }
    
    image = [self filterCIImage:image];

    cameras[num] = image;
    
    preview.ciImage = image;
    
    
    if(!self.mainOutput.needsDisplay){ //Spar på energien
        [preview setNeedsDisplay:YES];
        
        if(num == 0){
            self.mainOutput.ciImage = [self outputImage];
            if(![self.mainOutput needsDisplay])
                [self.mainOutput setNeedsDisplay:YES];
        }
    }
}

-(CIImage*) outputImage {
    CIImage * _outputImage;
    if(self.outSelector == 0){
        return nil;
    }
    if(self.outSelector > 0 && self.outSelector <= 3){
        _outputImage = cameras[self.outSelector-1];
    }
    
    
    [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1-self.master] forKey:@"inputColor"];
    
    [self.sourceOverFilter setValue:_outputImage forKey:@"inputBackgroundImage"];
    [self.sourceOverFilter setValue:[self.constantColorFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    _outputImage = [self.sourceOverFilter valueForKey:@"outputImage"];

    return _outputImage;
}


-(CIImage*) chromaKey:(CIImage*)image backgroundImage:(CIImage*)background{
    CIImage * retImage = image;
    __block float chromaMin;
    __block float chromaMax;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        
       chromaMin = [defaults floatForKey:@"chromaMin"];
       chromaMax = [defaults floatForKey:@"chromaMax"];
        
      
    });
    if(chromaMin != chromaMinSet || chromaMax != chromaMaxSet){
        chromaMinSet = chromaMin;
        chromaMaxSet = chromaMax;
        [self.chromaFilter setMinHueAngle:chromaMinSet maxHueAngle:chromaMaxSet];
    }
    
    
    self.chromaFilter.backgroundImage = background;
    self.chromaFilter.inputImage = image;
    retImage = [self.chromaFilter outputImage];

    return retImage;
}

-(CIImage*) filterCIImage:(CIImage*)inputImage{
    __block CIImage * _outputImage = inputImage;
    
    //    if(PropB(@"deinterlace")){
        [self.deinterlaceFilter setInputImage:_outputImage];
        _outputImage = [self.deinterlaceFilter valueForKey:@"outputImage"];
    //  }
    
    /* if(PropB(@"chromaKey") && inputImage == [self imageForSelector:1]){
     [chromaFilter setInputImage:_outputImage];
     [chromaFilter setBackgroundImage:[self imageForSelector:2]];
     _outputImage = [chromaFilter outputImage];
     }*/
    
    /* [blurFilter setValue:[NSNumber numberWithFloat:PropF(@"blur")] forKey:@"inputRadius"];
     [blurFilter setValue:_outputImage forKey:@"inputImage"];
     _outputImage = [blurFilter valueForKey:@"outputImage"];*/
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        
        [self.colorControlsFilter setValue:[defaults valueForKey:@"saturation"] forKey:@"inputSaturation"];
        /*[self.colorControlsFilter setValue:[NSNumber numberWithFloat:PropF(@"contrast")] forKey:@"inputContrast"];
         [self.colorControlsFilter setValue:[NSNumber numberWithFloat:PropF(@"brightness")] forKey:@"inputBrightness"];*/
        [self.colorControlsFilter setValue:_outputImage forKey:@"inputImage"];
        _outputImage = [self.colorControlsFilter valueForKey:@"outputImage"];
        
    /*    [self.dissolveFilter setValue:_outputImage forKey:@"inputImage"];
        [self.dissolveFilter setValue:@(self.master) forKey:@"inputTime"];
        _outputImage = [self.dissolveFilter valueForKey:@"outputImage"];
      */  
        
        
    });
    
    //   [self.gammaAdjustFilter setValue:[NSNumber numberWithFloat:PropF(@"gamma")] forKey:@"inputPower"];
    //  [self.gammaAdjustFilter setValue:_outputImage forKey:@"inputImage"];
    //  _outputImage = [self.gammaAdjustFilter valueForKey:@"outputImage"];
    
    /* [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep1")] forKey:@"inputPoint0"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep2")] forKey:@"inputPoint1"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep3")] forKey:@"inputPoint2"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep4")] forKey:@"inputPoint3"];
     [toneCurveFilter setValue:[CIVector numberWithFloat:PropF(@"curvep5")] forKey:@"inputPoint4"];
     [toneCurveFilter setValue:_outputImage forKey:@"inputImage"];
     _outputImage = [toneCurveFilter valueForKey:@"outputImage"];*/
    
    
    return _outputImage;
}

@end
