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
    self.outSelector = 1;
    
    
    //Movie
    
    NSError *error = nil;
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:@"/Users/jonas/Desktop/test3.mov" error:&error];
    
    videoWriter = [[AVAssetWriter alloc] initWithURL:
                   [NSURL fileURLWithPath:@"/Users/jonas/Desktop/test3.mov"] fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:720], AVVideoWidthKey,
                                   [NSNumber numberWithInt:576], AVVideoHeightKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput
                        assetWriterInputWithMediaType:AVMediaTypeVideo
                        outputSettings:videoSettings];
    
    
    adaptor = [AVAssetWriterInputPixelBufferAdaptor
               assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
               sourcePixelBufferAttributes:@{(NSString*)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB]}];
    
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    [videoWriter addInput:videoWriterInput];
    
    //Start a session:
    if(![videoWriter startWriting]){
        NSLog(@"Could not start writing %@",videoWriter.error);
    }
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    NSLog(@"%@",adaptor.pixelBufferPool);

    
    /*
    NSError * error;
    self.mMovie = [[QTMovie alloc] initToWritableData:[NSMutableData data] error:&error];
    if (!self.mMovie) {
        [[NSAlert alertWithError:error] runModal];
    }*/
    
    
    //Shortcuts
    
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSKeyDownMask) handler:^(NSEvent *incomingEvent) {
		NSLog(@"Events: %@",incomingEvent);
		
        //	if ([NSEvent modifierFlags] & NSAlternateKeyMask) {
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
            case 86:
            {
                self.recording = false;
                
                /* dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Play movie, time %lli",[self.mMovie duration].timeValue);
                    [self.mMovie gotoBeginning];
                    [self.mMovie play];
                });
                */
                self.outSelector = 4;
                break;
            }
                
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


-(void)setRecording:(bool)recording{
    if(recording != _recording){
    //    self.lastRecordTime = -1;
        _recording = recording;
        self.startRecordTime = [NSDate timeIntervalSinceReferenceDate];
        
        if(!recording){
     
            [videoWriterInput markAsFinished];
            [videoWriter finishWriting];
            NSLog(@"Write Ended");
       
        
        } else {
          
                 }
       /* if(recording){
            if([self.mMovie duration].timeValue > 0){
                QTTime qtTime = [self.mMovie duration];
                qtTime.timeValue --;
                NSValue * time = [NSValue valueWithQTTime:qtTime];
                
                NSDictionary * chapter = @{ QTMovieChapterName:@"Chapter", QTMovieChapterStartTime:time };
                
                NSError * error;
                NSMutableArray * chapters = [NSMutableArray arrayWithArray:self.mMovie.chapters];
                [chapters addObject:chapter];
                [self.mMovie addChapters:chapters withAttributes:@{} error:&error];
                if(error){
                    NSLog(@"Error %@",error);
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError * outError = nil;
                if(![self.mMovie writeToFile:@"/Users/jonas/Desktop/test.mov" withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:QTMovieFlatten] error:&outError]){
                    NSLog(@"Could not write %@",outError);
                }
                //    movieView.movie = mMovie;
            });
        }*/
    }
}

-(bool)recording{
    return _recording;
}



static dispatch_once_t onceToken;

-(void) newFrame:(DecklinkCallback*)callback{
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        [callback->lock lock];
        callback->delegateBusy = YES;
        CVPixelBufferRef buffer = [self createCVImageBufferFromCallback:callback];
        
        
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
        
        NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
        
        //      dispatch_sync(dispatch_get_main_queue(), ^{
        CIImage * image  = [CIImage imageWithCVImageBuffer:buffer];
        
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
        
        
        if(!self.recording){
            if(num == 0  && [[NSUserDefaults standardUserDefaults] boolForKey:@"chromaKey"]){
                image = [self chromaKey:image backgroundImage:cameras[1]];
            }
            
            image = [self filterCIImage:image];
            cameras[num] = image;
        

            //  dispatch_async(dispatch_get_main_queue(), ^{
            if(!preview.needsDisplay){ //Spar på energien
                preview.ciImage = image;
                [preview setNeedsDisplay:YES];
            }
            if(!self.mainOutput.needsDisplay){
                if(num == 0){
                    self.mainOutput.ciImage = [self outputImage];
                    if(![self.mainOutput needsDisplay])
                        [self.mainOutput setNeedsDisplay:YES];
                }
            }
            
            if(num==0){
                if(self.outSelector == 4){
                    //[self updateMovie];
                }
            }
            //   });
        }
        
        if(self.recording && num == self.outSelector - 1){
            //  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
            NSTimeInterval diffTime = time - self.startRecordTime;
            int frameCount = diffTime*25.0;
            
            BOOL append_ok = NO;
            int j = 0;
            /* while (!append_ok && j < 30)
                 {*/
                if (adaptor.assetWriterInput.readyForMoreMediaData)
                {
//                    printf("appending %d attemp %d\n", frameCount, j);
                    
                    CMTime frameTime = CMTimeMake(frameCount,(int32_t) 25.0);
                    append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                    
                    
                    if(buffer)
                        CVBufferRelease(buffer);
                    [NSThread sleepForTimeInterval:0.03];
                }
                else
                {
                    printf("adaptor not ready %d, %d\n", frameCount, j);
                    // [NSThread sleepForTimeInterval:0.1];
                }
                j++;
                //}
                if (!append_ok) {
                    printf("error appending image %d times %d\n", frameCount, j);
                }

           // });
            /*dispatch_once(&onceToken, ^{
                recordImage = [[NSImage alloc] initWithSize:NSMakeSize(720, 576)];
            });
            
            NSTimeInterval diff = [NSDate timeIntervalSinceReferenceDate] - self.lastRecordTime;
            if(self.lastRecordTime == -1){
                diff = 0;
            }
            diff *= 600;
            
            self.lastRecordTime = [NSDate timeIntervalSinceReferenceDate];
            
            NSBitmapImageRep * bitmap;
            
            unsigned char * bytes = callback->bytes;
            bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bytes
                                                             pixelsWide:callback->w pixelsHigh:callback->h
                                                          bitsPerSample:8 samplesPerPixel:4
                                                               hasAlpha:YES isPlanar:NO
                                                         colorSpaceName:NSDeviceRGBColorSpace
                                                           bitmapFormat:1
                                                            bytesPerRow:4*callback->w bitsPerPixel:8*4];
            
            
            
            [recordImage addRepresentation:bitmap];
            
            //dispatch_sync(dispatch_get_main_queue(), ^{
           // [self.mMovie addImage:recordImage forDuration:QTMakeTime(diff, 600) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys: @"jpeg", QTAddImageCodecType, nil]];
            //                [mMovie addImage:recordImage forDuration:QTMakeTime(timeDiff, 1000) withAttributes:nil];
            // [self.mMovie setCurrentTime:[self.mMovie duration]];
            [recordImage removeRepresentation:bitmap];
            //});
            */
            
            
        }
        
        callback->delegateBusy = NO;
        [callback->lock unlock];
    });
}
/*
 -(void) updateMovie{
 const CVTimeStamp * outputTime;
 QTVisualContextTask(movieTextureContext);
 if (movieTextureContext != NULL && QTVisualContextIsNewImageAvailable(movieTextureContext, outputTime)) {
 // if we have a previous frame release it
 if (NULL != movieCurrentFrame) {
 CVOpenGLTextureRelease(movieCurrentFrame);
 movieCurrentFrame = NULL;
 }
 // get a "frame" (image buffer) from the Visual Context, indexed by the provided time
 OSStatus status = QTVisualContextCopyImageForTime(movieTextureContext, NULL, outputTime, &movieCurrentFrame);
 
 // the above call may produce a null frame so check for this first
 // if we have a frame, then draw it
 if ( ( status != noErr ) && ( movieCurrentFrame != NULL ) ){
 NSLog(@"Error: OSStatus: %ld",status);
 CFRelease( movieCurrentFrame );
 
 movieCurrentFrame = NULL;
 }
 } else if  (movieTextureContext == NULL){
 NSLog(@"No textureContext");
 if (NULL != movieCurrentFrame) {
 CVOpenGLTextureRelease(movieCurrentFrame);
 movieCurrentFrame = NULL;
 }
 }
 }*/

-(CIImage*) outputImage {
    CIImage * _outputImage;
    if(self.outSelector == 0){
        [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
        return [self.constantColorFilter valueForKey:@"outputImage"];
    }
    if(self.outSelector > 0 && self.outSelector <= 3){
        _outputImage = cameras[self.outSelector-1];
    }
    /* if(self.outSelector == 4){
     _outputImage = [CIImage imageWithCVImageBuffer:movieCurrentFrame];
     _outputImage = [self filterCIImage:_outputImage];
     }*/
    
    
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
    //dispatch_sync(dispatch_get_main_queue(), ^{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    chromaMin = [defaults floatForKey:@"chromaMin"];
    chromaMax = [defaults floatForKey:@"chromaMax"];
    
    
    //  });
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
    
    //  dispatch_sync(dispatch_get_main_queue(), ^{
    
    
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
    
    
    //});
    
    [self.gammaAdjustFilter setValue:[defaults valueForKey:@"gamma"] forKey:@"inputPower"];
    [self.gammaAdjustFilter setValue:_outputImage forKey:@"inputImage"];
    _outputImage = [self.gammaAdjustFilter valueForKey:@"outputImage"];
    
    /* [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep1")] forKey:@"inputPoint0"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep2")] forKey:@"inputPoint1"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep3")] forKey:@"inputPoint2"];
     [toneCurveFilter setValue:[NSNumber numberWithFloat:PropF(@"curvep4")] forKey:@"inputPoint3"];
     [toneCurveFilter setValue:[CIVector numberWithFloat:PropF(@"curvep5")] forKey:@"inputPoint4"];
     [toneCurveFilter setValue:_outputImage forKey:@"inputImage"];
     _outputImage = [toneCurveFilter valueForKey:@"outputImage"];*/
    
    
    return _outputImage;
}

-(CVPixelBufferRef) createCVImageBufferFromCallback:(DecklinkCallback*)callback{
    int w = callback->w;
    int h = callback->h;
    unsigned char * bytes = callback->bytes;
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    
    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, w, h, k32ARGBPixelFormat, bytes, 4*w, (CVPixelBufferReleaseBytesCallback )nil, (void*)nil, (__bridge CFDictionaryRef)d, &buffer);
    
    return buffer;
}




@end
