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

static void *ItemStatusContext = &ItemStatusContext;
static void *SelectionContext = &SelectionContext;


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
    
    self.recordings = [NSMutableArray array];
    
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
    
    self.readyToRecord = YES;
    
    
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
    
    
    [self.recordingsArrayController addObserver:self forKeyPath:@"selection" options:0 context:&SelectionContext];
    
    
    NSMutableArray * inputs = [NSMutableArray array];
    [inputs addObject:@{@"name":@"Main A", @"number":@(1)}];
    [inputs addObject:@{@"name":@"Main B", @"number":@(2)}];
    
    self.cameraInputs = inputs;
    
    [self addObserver:self forKeyPath:@"decklink1input" options:0 context:nil];
    [self addObserver:self forKeyPath:@"decklink2input" options:0 context:nil];
    [self addObserver:self forKeyPath:@"decklink3input" options:0 context:nil];
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    [BeamSync enable];
    [[NSUserDefaults standardUserDefaults] setInteger:self.recordingIndex forKey:@"recordingIndex"];
    
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if([keyPath isEqualToString:@"decklink1input"]){
        [self.mavController setKey:<#(NSString *)#>]
    }
    if(context == &ItemStatusContext){
        if(avPlayer.error){
            NSLog(@"Error loading %@",avPlayer.error);
        }
        
        //   [avPlayer play];
        [self.mainOutput setWantsLayer:YES];
        avPlayerLayer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] CGColor];
        avPlayerLayer.videoGravity =  AVLayerVideoGravityResize;
        [avPlayerLayer setFrame:[[self.mainOutput layer] bounds]];
        [avPlayerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
        [[self.mainOutput layer] addSublayer:avPlayerLayer];
        [avPlayer play];
        NSLog(@"Play %lli",        [avPlayer.currentItem duration].value);
    }
    if(context == &SelectionContext){
        NSLog(@"Selection");
        avPlayerBoundaryPreview = nil;

        if([self.recordingsArrayController.selectedObjects count]==0){
            [avPlayerLayerPreview removeFromSuperlayer];
            [avPlayerPreview pause];
            
        } else {
            NSDictionary * selection = self.recordingsArrayController.selectedObjects[0];
            //NSLog(@"%@",selection);
            AVPlayerItem * item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",[selection valueForKey:@"path"]]]];
            
            NSNumber * inTime = [selection valueForKey:@"inTime"];
          /*  if(inTime){
                [item seekToTime:CMTimeMake([inTime floatValue], 25)];
            }
            */

            
            if(item.error){
                NSLog(@"Error loading %@",item.error);
            }
            //      [item addObserver:self forKeyPath:@"status" options:0 context:&ItemStatusContext];
            
            while([[[self.videoView layer]sublayers] count] > 0){
                [[[self.videoView layer]sublayers][0] removeFromSuperlayer];
            }
            [avPlayerPreview pause];
            
            avPlayerPreview = [AVPlayer playerWithPlayerItem:item];
            [avPlayerPreview play];
            avPlayerLayerPreview = [AVPlayerLayer playerLayerWithPlayer:avPlayerPreview];
            
            [self.videoView setWantsLayer:YES];
            avPlayerLayerPreview.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] CGColor];
            avPlayerLayerPreview.videoGravity =  AVLayerVideoGravityResize;
            [avPlayerLayerPreview setFrame:[[self.videoView layer] bounds]];
            [avPlayerLayerPreview setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
            [[self.videoView layer] addSublayer:avPlayerLayerPreview];
            
            
            [self updateInOutTime:self];

       /*
            CATextLayer *textLayer=[CATextLayer layer];
            [textLayer setForegroundColor:[[NSColor blackColor] CGColor]];
        //    [textLayer setContentsScale:[[NSScreen mainScreen] conte]];
            [textLayer setFrame:CGRectMake(50, 170, 250, 20)];
            [textLayer setString:(id)@"asdfasd"];
        
            [[self.videoView layer] addSublayer:textLayer];*/
        }
        
    }
}


- (IBAction)loadLastVideos:(id)sender {
    [self willChangeValueForKey:@"recordings"];
    
    self.recordingIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"recordingIndex"] ;
    for(int i=0;i<self.recordingIndex-1;i++){
        NSString * path = [NSString stringWithFormat:@"/Users/jonas/Desktop/triumf%i.mov",i+1];
        
        //AVPlayerItem * item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",path]]];
        NSMutableDictionary * dict = [@{@"path":path, @"name":[NSString stringWithFormat:@"Old Rec %i", i], @"inTime":@(0), @"outTime":@(0)} mutableCopy];
        [self.recordings addObject:dict];
        
        
    }
    NSLog(@"Recordings loaded: %@",self.recordings);
    [self didChangeValueForKey:@"recordings"];
}

- (IBAction)updateInOutTime:(id)sender {
    NSDictionary * selection = self.recordingsArrayController.selectedObjects[0];
    NSNumber * inTime = [selection valueForKey:@"inTime"];
    NSNumber * outTime = [selection valueForKey:@"outTime"];
    if(inTime && outTime){
        if([inTime floatValue] == 0){
            inTime = @(1);
        }
        if([inTime floatValue] >= avPlayerPreview.currentItem.duration.value){
            inTime = @(avPlayerPreview.currentItem.duration.value);
        }
        if([outTime floatValue] >= avPlayerPreview.currentItem.duration.value){
            outTime = @(avPlayerPreview.currentItem.duration.value);
        }

        [avPlayerPreview.currentItem seekToTime:CMTimeMake([inTime floatValue], 600) toleranceBefore: kCMTimeZero toleranceAfter: kCMTimeZero];

       // [avPlayerPreview.currentItem a]
        
        if(avPlayerBoundaryPreview){
            [avPlayerPreview removeTimeObserver:avPlayerBoundaryPreview];
            avPlayerBoundaryPreview = nil;
        }
        
        long long time = avPlayerPreview.currentItem.duration.value - [outTime floatValue];
        if(time > 0){
            NSValue * val = [NSValue valueWithCMTime:CMTimeMake(time, 600)];
            
            __block AppDelegate *dp = self;
            avPlayerBoundaryPreview= [avPlayerPreview addBoundaryTimeObserverForTimes:@[val] queue: NULL usingBlock:^{
                [dp->avPlayerPreview pause];
            }];
        }
        [avPlayerPreview play];
    }
    
    
}


-(void)setPlayVideo:(bool)playVideo{
    if(_playVideo != playVideo){
        _playVideo = playVideo;
        
        if(playVideo){
            int i=0;
            NSMutableArray * items = [NSMutableArray array];
            NSMutableArray * outTimes = [NSMutableArray array];
            
            for(NSDictionary * recording in self.recordings){
                AVPlayerItem * item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",[recording valueForKey:@"path"]]]];

                NSNumber * inTime = [recording valueForKey:@"inTime"];
                NSNumber * outTime = [recording valueForKey:@"outTime"];
                if([inTime floatValue] == 0){
                    inTime = @(100);
                }
                if([inTime floatValue] >= avPlayerPreview.currentItem.duration.value){
                    inTime = @(avPlayerPreview.currentItem.duration.value);
                }
               
                
                if([outTime floatValue] >= avPlayerPreview.currentItem.duration.value){
                    outTime = @(avPlayerPreview.currentItem.duration.value);
                }
                if([outTime floatValue] == 0){
                    outTime = @(200);
                }
                [item seekToTime:CMTimeMake([inTime floatValue], 600)  toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
                [outTimes addObject:[NSValue valueWithCMTime:CMTimeMake([outTime floatValue], 600) ]];
                
                if(item.error){
                    NSLog(@"Error loading %@",item.error);
                }
                if(i==0){
                    [item addObserver:self forKeyPath:@"status" options:0 context:&ItemStatusContext];
                }
                [items addObject:item];
                i++;
            }
            
            avPlayer = [[AVQueuePlayer alloc] initWithItems:items];
           // [avPlayer play];
            avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:avPlayer];
/*
            __block AppDelegate *dp = self;
            void (^block)(void)  = ^(void){
                [dp->avPlayer removeTimeObserver:dp->avPlayerBoundaryPreview];
                [dp->avPlayer advanceToNextItem];
                NSLog(@"Ping");
            };
            

             avPlayerBoundaryPreview = [avPlayer addBoundaryTimeObserverForTimes:@[outTimes[0]] queue:NULL usingBlock:block];
            
            */
            avPlayerLayer.filters = @[self.colorControlsFilter, self.gammaAdjustFilter];
        } else {
            [avPlayerLayer removeFromSuperlayer];
            [self.mainOutput setWantsLayer:NO];
        }
        
    }
}

-(bool)playVideo{
    return _playVideo;
}


-(void)setRecording:(bool)recording{
    if(recording != _recording){
        //    self.lastRecordTime = -1;
        _recording = recording;
        self.startRecordTime = [NSDate timeIntervalSinceReferenceDate];
        
        if(!recording){
            [self willChangeValueForKey:@"recordings"];
            
            NSString * path = [NSString stringWithFormat:@"/Users/jonas/Desktop/triumf%i.mov",self.recordingIndex];
            
            [videoWriterInput markAsFinished];
            [videoWriter finishWriting];
            
//            [self.recordings addObject:@{@"path":path, @"name":[NSString stringWithFormat:@"Rec %i", self.recordingIndex-1]}];
            NSMutableDictionary * dict = [@{@"path":path, @"name":[NSString stringWithFormat:@"Old Rec %i", self.recordingIndex-1], @"inTime":@(0), @"outTime":@(0)} mutableCopy];
            [self.recordings addObject:dict];

            
            NSLog(@"Write Ended");
            
            [NSThread sleepForTimeInterval:0.1];
            self.readyToRecord = YES;
            [self didChangeValueForKey:@"recordings"];
            
            
        } else if(self.readyToRecord){
            self.readyToRecord = NO;
            
            NSError *error = nil;
            
            self.recordingIndex ++;
            [[NSUserDefaults standardUserDefaults] setInteger:self.recordingIndex forKey:@"recordingIndex"];
            
            NSString * path = [NSString stringWithFormat:@"/Users/jonas/Desktop/triumf%i.mov",self.recordingIndex];
            NSFileManager * fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtPath:path error:&error];
            
            videoWriter = [[AVAssetWriter alloc] initWithURL:
                           [NSURL fileURLWithPath:path] fileType:AVFileTypeQuickTimeMovie
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
            
            [NSThread sleepForTimeInterval:0.1];
            
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
        //NSLog(@"%lld",[avPlayer currentTime].value);
        
        
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
                [NSThread sleepForTimeInterval:0.035];
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
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    float chromaMin = [defaults floatForKey:@"chromaMin"];
    float chromaMax = [defaults floatForKey:@"chromaMax"];
    
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
