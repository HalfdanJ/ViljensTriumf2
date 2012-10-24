//
//  AppDelegate.m
//  ViljensTriumf
//
//  Created by Jonas on 10/10/12.
//  Copyright (c) 2012 Jonas. All rights reserved.
//

#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import <CoreMIDI/CoreMIDI.h>
#import "BeamSync.h"
#import "MyAVPlayerItem.h"

@implementation AppDelegate

static void *ItemStatusContext = &ItemStatusContext;
static void *ItemStatusContextPreview = &ItemStatusContextPreview;
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
    
    self.mavController = [[MavController alloc] init];
    
    self.recordings = [NSMutableArray array];
    
    //
    //Init filters
    //
    self.noiseReductionFilter = [CIFilter filterWithName:@"CINoiseReduction"] ;
    [self.noiseReductionFilter setDefaults];
    
    self.colorControlsFilter = [CIFilter filterWithName:@"CIColorControls"] ;
    [self.colorControlsFilter setDefaults];
    
    self.gammaAdjustFilter = [CIFilter filterWithName:@"CIGammaAdjust"];
    [self.gammaAdjustFilter setDefaults];
    
    self.toneCurveFilter = [CIFilter filterWithName:@"CIToneCurve"];
    [self.toneCurveFilter setDefaults];
    
    self.dissolveFilter = [CIFilter filterWithName:@"CIDissolveTransition"];
    [self.dissolveFilter setDefaults];
    
    self.perspectiveFilter = [CIFilter filterWithName:@"CIPerspectiveTransform"];
    [self.perspectiveFilter setDefaults];
    
    self.perspectiveFilterMovie= [CIFilter filterWithName:@"CIPerspectiveTransform"];
    [self.perspectiveFilterMovie setDefaults];
    [self updateKeystone:self];
    

    
    self.constantColorFilter = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    [self.constantColorFilter setValue:[CIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
    
    
    self.sourceOverFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    
    self.deinterlaceFilter = [[DeinterlaceFilter alloc] init];
    
   // [self.deinterlaceFilter setDefaults];
    
    
    self.widescreenFilter = [CIFilter filterWithName:@"CIAffineTransform"];
    [self.widescreenFilter setDefaults];
    NSAffineTransform * transform = [NSAffineTransform transform];
    [transform scaleXBy:1.333 yBy:1.0];
    [transform translateXBy:-120 yBy:0];
    [self.widescreenFilter setValue:transform forKey:@"inputTransform"];
    
    
    self.chromaTransform = [CIFilter filterWithName:@"CIAffineTransform"];
    [self.chromaTransform setDefaults];
    
    self.chromaCrop = [CIFilter filterWithName:@"CICrop"];
    [self.chromaCrop setDefaults];
    
    
    [self updateChromaTransform];

    
    self.dslrFilter = [CIFilter filterWithName:@"CIAffineTransform"];
    [self.dslrFilter setDefaults];
    transform = [NSAffineTransform transform];
    //[transform scaleXBy:1.333 yBy:1.0];
    [transform translateXBy:-100 yBy:-100];
    [transform scaleBy:1.28];
    [self.dslrFilter setValue:transform forKey:@"inputTransform"];
    
    self.chromaFilter = [[ChromaFilter alloc] init];
    self.chromaFilter.name = @"chroma";
    
    self.master = 1.0;
    self.outSelector = 1;
    
    
    //Movie
    
    self.readyToRecord = YES;
    
    transitionTime = -1;
    
    
    //Shortcuts
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSKeyDownMask) handler:^(NSEvent *incomingEvent) {
		NSLog(@"Events: %@",incomingEvent);
        switch ([incomingEvent keyCode]) {
            case 82:
                self.outSelector = 0;
                transitionTime = 0;
                break;
                
            case 83:
                self.outSelector  = 1;
                transitionTime = 0;
                break;
            case 84:
                self.outSelector  = 2;
                transitionTime = 0;
                break;
            case 85:
                self.outSelector  = 3;
                transitionTime = 0;
                break;
                
            case 76:
                [avPlayer advanceToNextItem];
                break;
            default:
                return incomingEvent;
                
                break;
        }
        
        
        
        return (NSEvent*)nil;
    }];
    
    
    [self.recordingsArrayController addObserver:self forKeyPath:@"selection" options:0 context:&SelectionContext];
    
    
    NSMutableArray * inputs = [NSMutableArray array];
    [inputs addObject:@{@"name":@"1 Main A"}];
    [inputs addObject:@{@"name":@"2 Main B"}];
    [inputs addObject:@{@"name":@"3 Main C"}];
    [inputs addObject:@{@"name":@"4 Dolly"}];
    [inputs addObject:@{@"name":@"5"}];
    [inputs addObject:@{@"name":@"6 Cam 5 Model"}];
    [inputs addObject:@{@"name":@"7 Lærred"}];
    [inputs addObject:@{@"name":@"8 Ude"}];
    [inputs addObject:@{@"name":@"9 Greenscreen"}];
    [inputs addObject:@{@"name":@"10"}];
    [inputs addObject:@{@"name":@"11  ---- "}];
    [inputs addObject:@{@"name":@"12 PTZ"}];    
    [inputs addObject:@{@"name":@"13 Cam 5 kort "}];
    [inputs addObject:@{@"name":@"14 Mercedes front"}];
    [inputs addObject:@{@"name":@"15 Model (quad)"}];
    [inputs addObject:@{@"name":@"16 Mercedes overshoulder"}];
    self.cameraInputs = inputs;
    
    self.decklink1input = -1;
    self.decklink2input = -1;
    self.decklink3input = -1;
    [self.mavController.outputPatch[0] bind:@"input" toObject:self withKeyPath:@"decklink1input" options:nil];
    [self.mavController.outputPatch[1] bind:@"input" toObject:self withKeyPath:@"decklink2input" options:nil];
    [self.mavController.outputPatch[2] bind:@"input" toObject:self withKeyPath:@"decklink3input" options:nil];
    
    //    [self addObserver:self forKeyPath:@"decklink1input" options:0 context:nil];
    for(int i=0;i<3;i++){
        [self.mavController.outputPatch[i] addObserver:self forKeyPath:@"input" options:0 context:(void*)@(i)];
    }
    
    [self.mavController readAllOutputs];
    
    
    MIDIClientRef client = 0;
    MIDIClientCreate(CFSTR("ViljensTriumf"), MyMIDINotifyProc, (__bridge void*)(self), &client);
    
    MIDIPortRef inPort = 0;
    MIDIInputPortCreate(client, CFSTR("Input Port"), MyMIDIReadProc, (__bridge void*)(self), &inPort);
    
    ItemCount sourceCount = MIDIGetNumberOfSources();
    for(ItemCount i=0; i<sourceCount; i++){
        MIDIEndpointRef source = MIDIGetSource(i);
        if(source != 0){
            MIDIPortConnectSource(inPort, source, NULL);
        }
    }
    
    
    
    avPlayerLayerPreview = [[AVPlayerLayer alloc] init];

}

-(void)setOutSelector:(int)outSelector{
    [self willChangeValueForKey:@"out1selected"];
    [self willChangeValueForKey:@"out2selected"];
    [self willChangeValueForKey:@"out3selected"];
    
    _outSelector = outSelector;
    
    [self didChangeValueForKey:@"out1selected"];
    [self didChangeValueForKey:@"out2selected"];
    [self didChangeValueForKey:@"out3selected"];
    
}

-(void)updateChromaTransform{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

    /*NSAffineTransform * transform = [NSAffineTransform transform];
    [transform translateXBy:[defaults floatForKey:@"chromaX"] yBy:[defaults floatForKey:@"chromaY"]];
    [transform scaleXBy:[defaults floatForKey:@"chromaScale"] yBy:[defaults floatForKey:@"chromaScale"]];
    [self.chromaTransform setValue:transform forKey:@"inputTransform"];
  */
    
    CIVector * vec = [CIVector vectorWithX:[defaults floatForKey:@"chromaX"] Y:[defaults floatForKey:@"chromaY"] Z:720*[defaults floatForKey:@"chromaScale"] W:576*[defaults floatForKey:@"chromaScale"]];
    [self.chromaCrop setValue:vec forKey:@"inputRectangle"];


}
- (IBAction)updateKeystone:(id)sender {
    NSUserDefaults * settings = [NSUserDefaults standardUserDefaults];
    [self.perspectiveFilter setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c1x"]*720.0 Y:[settings floatForKey:@"c1y"]*576.0] forKey:@"inputTopLeft"];
    
    [self.perspectiveFilter setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c2x"]*720.0 Y:[settings floatForKey:@"c2y"]*576.0] forKey:@"inputTopRight"];
    
    [self.perspectiveFilter setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c3x"]*720.0 Y:[settings floatForKey:@"c3y"]*576.0] forKey:@"inputBottomRight"];
    
    [self.perspectiveFilter setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c4x"]*720.0 Y:[settings floatForKey:@"c4y"]*576.0] forKey:@"inputBottomLeft"];

    [self.perspectiveFilterMovie setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c1x"]*1024 Y:[settings floatForKey:@"c1y"]*768] forKey:@"inputTopLeft"];
    
    [self.perspectiveFilterMovie setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c2x"]*1024 Y:[settings floatForKey:@"c2y"]*768] forKey:@"inputTopRight"];
    
    [self.perspectiveFilterMovie setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c3x"]*1024 Y:[settings floatForKey:@"c3y"]*768] forKey:@"inputBottomRight"];
    
    [self.perspectiveFilterMovie setValue:[[CIVector alloc] initWithX:[settings floatForKey:@"c4x"]*1024 Y:[settings floatForKey:@"c4y"]*768] forKey:@"inputBottomLeft"];

   
}

-(int)outSelector{
    return _outSelector;
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    [BeamSync enable];
    [[NSUserDefaults standardUserDefaults] setInteger:self.recordingIndex forKey:@"recordingIndex"];
    
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if([keyPath isEqualToString:@"input"]){
        NSNumber * output = (__bridge NSNumber*) context;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if([output intValue] == 0){
                [self willChangeValueForKey:@"out1name"];
                self.decklink1input = [[object valueForKey:@"input"] intValue];
                [self didChangeValueForKey:@"out1name"];
                
            }
            if([output intValue] == 1){
                [self willChangeValueForKey:@"out2name"];
                self.decklink2input = [[object valueForKey:@"input"] intValue];
                [self didChangeValueForKey:@"out2name"];
                
            }
            if([output intValue] == 2){
                [self willChangeValueForKey:@"out3name"];
                self.decklink3input = [[object valueForKey:@"input"] intValue];
                [self didChangeValueForKey:@"out3name"];
                
            }
        });
    }

    
    if(context == &ItemStatusContext){
        if(avPlayer.error){
            NSLog(@"Error loading %@",avPlayer.error);
        } else {
            NSLog(@"Loaded player item");
        }
        
        //   [avPlayer play];
                NSLog(@"Play %lli",        [avPlayer.currentItem duration].value);
    }
    
    if(context == &ItemStatusContextPreview){
        NSLog(@"Preview status");
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
            
            [item addObserver:self forKeyPath:@"status" options:0 context:&ItemStatusContextPreview];
            
            if(item.duration.value > 0){
                
                NSLog(@"Duration: %lli",item.duration.value);
                //   NSNumber * inTime = [selection valueForKey:@"inTime"];
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
                [avPlayerLayerPreview setPlayer:avPlayerPreview];
                
                [self.videoView setWantsLayer:YES];
                avPlayerLayerPreview.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] CGColor];
                avPlayerLayerPreview.videoGravity =  AVLayerVideoGravityResize;
                [avPlayerLayerPreview setFrame:[[self.videoView layer] bounds]];
                [avPlayerLayerPreview setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
                [[self.videoView layer] addSublayer:avPlayerLayerPreview];
                
                
                
                [self performSelector:@selector(updateInOutTime:) withObject:self afterDelay:0];
            } else {
                NSLog(@"No duration on selected movie!!");
                
                while([[[self.videoView layer]sublayers] count] > 0){
                    [[[self.videoView layer]sublayers][0] removeFromSuperlayer];
                }
            }
            // [self updateInOutTime:self];
            
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

- (IBAction)clearVideos:(id)sender {
    [self willChangeValueForKey:@"recordings"];
    
    self.recordingIndex = 0;
    [self.recordings removeAllObjects];
    [self didChangeValueForKey:@"recordings"];
    
}

- (IBAction)loadLastVideos:(id)sender {
    [self willChangeValueForKey:@"recordings"];
    
    self.recordingIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"recordingIndex"] ;
    NSLog(@"Load %i",self.recordingIndex);
    for(int i=1;i<=self.recordingIndex;i++){
        NSString * path = [NSString stringWithFormat:@"/Users/jonas/Desktop/triumf%i.mov",i];
        
        //AVPlayerItem * item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",path]]];
        NSMutableDictionary * dict = [@{@"path":path, @"chroma":@(NO), @"active": @(YES), @"name":[NSString stringWithFormat:@"Old Rec %i", i], @"inTime":@(0), @"outTime":@(0)} mutableCopy];
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
//        NSLog(@"Update inout %@ %@",inTime, outTime);
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
        
        /*  if(avPlayerBoundaryPreview){
         [avPlayerPreview removeTimeObserver:avPlayerBoundaryPreview];
         avPlayerBoundaryPreview = nil;
         }
         
         long long time = avPlayerPreview.currentItem.duration.value - [outTime floatValue];
         if(time < 0){
         time = 1;
         }
         if(time > 0){
         NSValue * val = [NSValue valueWithCMTime:CMTimeMake(time, 600)];
         NSLog(@"Block %@",val);
         __block AppDelegate *dp = self;
         avPlayerBoundaryPreview= [avPlayerPreview addBoundaryTimeObserverForTimes:@[val] queue: NULL usingBlock:^{
         [dp->avPlayerPreview pause];
         
         [dp->avPlayerPreview removeTimeObserver:dp->avPlayerBoundaryPreview];
         dp->avPlayerBoundaryPreview = nil;
         
         NSLog(@"Block ping");
         }];
         }*/
        [avPlayerPreview play];
    }
    
    
}

-(void)playerItemDidReachEnd:(id)object{
    MyAVPlayerItem * item = [object valueForKey:@"object"];
    NSLog(@"reach end %@ chroma %@",item,item.chromaKey);
    NSLog(@"Items %@",avPlayer.items);
    
    if(avPlayer.items.count > 1){
        MyAVPlayerItem * nextItem = avPlayer.items[1];
        if(nextItem){
            NSLog(@"Next item chroma: %@",nextItem.chromaKey);
            if([nextItem.chromaKey boolValue]){
                avPlayerLayer.filters = @[ self.deinterlaceFilter, self.chromaFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
                //   avPlayerLayer.filters = @[ self.deinterlaceFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
            } else {
                avPlayerLayer.filters = @[ self.deinterlaceFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
            }
        }
    }
    
    
}

-(void)setPlayVideo:(bool)playVideo{
    if(_playVideo != playVideo){
        _playVideo = playVideo;
        
        if(playVideo){
            int i=0;
            NSMutableArray * items = [NSMutableArray array];
         //   NSMutableArray * outTimes = [NSMutableArray array];
            
            for(NSDictionary * recording in self.recordings){
                if([[recording valueForKey:@"active"] boolValue] == YES){
                    MyAVPlayerItem * item = [[MyAVPlayerItem alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",[recording valueForKey:@"path"]]]];

                    item.chromaKey = [recording valueForKey:@"chroma"] ;
                    if(item.duration.value > 0){
                        double inTime = [[recording valueForKey:@"inTime"] doubleValue];
                //        double outTime = item.duration.value - [[recording valueForKey:@"outTime"] doubleValue];
                        
                        if(inTime == 0){
                            inTime = 100;
                        }
                        if(inTime >= item.duration.value){
                            inTime = item.duration.value;
                        }
                        
                        
                        /*  if(outTime >= avPlayerPreview.currentItem.duration.value){
                         outTime = avPlayerPreview.currentItem.duration.value;
                         }
                         if(outTime == 0){
                         outTime = 200;
                         }*/
                        [item seekToTime:CMTimeMake(inTime, 600)  toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
                       // [outTimes addObject:[NSValue valueWithCMTime:CMTimeMake(outTime, 600) ]];
                        
                        if(item.error){
                            NSLog(@"Error loading %@",item.error);
                        }
                        if(i==0){
                            [item addObserver:self forKeyPath:@"status" options:0 context:&ItemStatusContext];
                        }
                        
                        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                 selector:@selector(playerItemDidReachEnd:)
                                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                                   object:item];

                        [items addObject:item];
                    }
                    i++;
                }
            }
            
            avPlayer = [[AVQueuePlayer alloc] initWithItems:items];
            avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:avPlayer];
            NSRect bounds = NSMakeRect(0, 0, 720, 576);
            NSRect frame = NSMakeRect(0, 0, 1024, 768);
            [avPlayerLayer setFrame:frame];
            [avPlayerLayer setBounds:bounds];

/*            [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
            [self.sourceOverFilter setValue:[self.constantColorFilter valueForKey:@"outputImage"] forKey:@"inputBackgroundImage"];
  */
         //   [self.chromaFilter setInputBackgroundImage:[self imageForSelector:2]];
            
//           avPlayerLayer.filters = @[ self.deinterlaceFilter, self.chromaFilter];//, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
         //   avPlayerLayer.filters = @[ self.deinterlaceFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
            
            
            [self.mainOutput setWantsLayer:YES];
            avPlayerLayer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] CGColor];
            //avPlayerLayer.videoGravity =  AVLayerVideoGravityResize;
            //     [avPlayerLayer setFrame:[[self.mainOutput layer] bounds]];
            //xavPlayerLayer.transform
            
            [avPlayerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
            [self.mainOutput layer].backgroundColor = [[NSColor blackColor] CGColor];
            [[self.mainOutput layer] addSublayer:avPlayerLayer];
            [avPlayer play];
            
            
            if(items.count > 0){
                if([[items[0] valueForKey:@"chromaKey"] boolValue]){
                    avPlayerLayer.filters = @[ self.deinterlaceFilter, self.chromaFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
                    //   avPlayerLayer.filters = @[ self.deinterlaceFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
                } else {
                    avPlayerLayer.filters = @[ self.deinterlaceFilter, self.colorControlsFilter, self.gammaAdjustFilter];//, self.perspectiveFilterMovie, self.sourceOverFilter];
                }
            }
            
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
            NSMutableDictionary * dict = [@{@"path":path, @"active": @(YES), @"chroma":@(NO), @"name":[NSString stringWithFormat:@"Old Rec %i", self.recordingIndex-1], @"inTime":@(0), @"outTime":@(0)} mutableCopy];
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
            
            [NSThread sleepForTimeInterval:0.1];
            
        }
    }
}

-(bool)recording{
    return _recording;
}



static dispatch_once_t onceToken;

-(void) newFrame:(DecklinkCallback*)callback{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"%lld",[avPlayer currentTime].value);
        
        //NSLog(@"New frame in %i",callback);

        [callback->lock lock];
        callback->delegateBusy = YES;
//        CVPixelBufferRef buffer = [self createCVImageBufferFromCallback:callback];
        CVPixelBufferRef buffer = callback->buffer;
        
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
        
        
        if(self.playVideo){
            if(num == 1){
//            avPlayerLayer.filters
                ChromaFilter * filter = [avPlayerLayer valueForKeyPath:@"filters.chroma"];
                if(filter){
   //             NSLog(@" Filter %@",avPlayerLayer.filters);
                image = [self filterCIImage:image];
                
                
                [avPlayerLayer  setValue:image forKeyPath:@"filters.chroma.inputBackgroundImage"];
                }

            }
        } else {
            if(!self.recording){
                if(num == 0  && [[NSUserDefaults standardUserDefaults] boolForKey:@"chromaKey"] && self.decklink1input == 8){
                    image = [self chromaKey:image backgroundImage:cameras[1]];
                }
                if(num == 0 && [[NSUserDefaults standardUserDefaults] floatForKey:@"chromaScale"] != 1 && self.decklink1input == 8){
                    [self updateChromaTransform];
                    //                [self.chromaTransform setValue:image forKey:@"inputImage"];
                    //                image = [self.chromaTransform valueForKey:@"outputImage"];
                    
                    [self.chromaCrop setValue:image forKey:@"inputImage"];
                    image = [self.chromaCrop valueForKey:@"outputImage"];
                }
                
                image = [self filterCIImage:image];
                
                
                cameras[num] = image;
                
                
                //  dispatch_async(dispatch_get_main_queue(), ^{
                
                if(num == self.outSelector-1 || self.outSelector == 0 || self.outSelector > 3){
                    self.mainOutput.ciImage = [self outputImage];
                    //if(![self.mainOutput needsDisplay])
                    [self.mainOutput setNeedsDisplay:YES];
                }
                //            if(!self.mainOutput.needsDisplay){ //Spar på energien
                preview.ciImage = [self imageForSelector:num+1];
                //     [preview performSelector:@selector(setNeedsDisplay:) withObject:YES afterDelay:1];
                [preview setNeedsDisplay:YES];
                //          }
                //[NSThread sleepForTimeInterval:0.01];
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
                    
                    
                    //if(buffer)
                    //  CVBufferRelease(buffer);
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
            }
        }
        
        callback->delegateBusy = NO;
        [callback->lock unlock];
        //        NSLog(@"New frame out %i",callback);

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

-(CIImage*) imageForSelector:(int)selector{
    if(selector == 0){
        [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
        return [self.constantColorFilter valueForKey:@"outputImage"];
    }
    if(selector > 0 && selector <= 3){
        CIImage * img = cameras[selector-1];
        
        int inputSelector = self.decklink1input;
        if(selector == 2)
            inputSelector = self.decklink2input;
        if(selector == 3)
            inputSelector = self.decklink3input;
        
        if(inputSelector == 15){ //6 Jonas
            [self.widescreenFilter setValue:img forKey:@"inputImage"];
            img = [self.widescreenFilter valueForKey:@"outputImage"];
        }
/*        if(inputSelector == 9){ //10 DSLR
            [self.dslrFilter setValue:img forKey:@"inputImage"];
            img = [self.dslrFilter valueForKey:@"outputImage"];
        }*/
        
        return img;
    }
    return nil;
}
-(void)updateTransitionTime {
    
    transitionTime += 0.51-self.fadeTime*0.5;
    if(transitionTime < 1)
        [self performSelector:@selector(updateTransitionTime) withObject:nil afterDelay:0.01];
    
}

-(bool)out1selected{
    return self.outSelector == 1 || transitionImageSourceSelector == 1;
}
-(bool)out2selected{
    return self.outSelector == 2 || transitionImageSourceSelector == 2;;
}
-(bool)out3selected{
    return self.outSelector == 3 || transitionImageSourceSelector == 3;
}

-(NSString *)out1name{
    if(self.decklink1input < [self.cameraInputs count])
        return [self.cameraInputs[self.decklink1input] valueForKey:@"name"];
    return @"";
}
-(NSString *)out2name{
    if(self.decklink2input < [self.cameraInputs count])
        return [self.cameraInputs[self.decklink2input] valueForKey:@"name"];
    return @"";
}
-(NSString *)out3name{
    if(self.decklink3input < [self.cameraInputs count])
        return [self.cameraInputs[self.decklink3input] valueForKey:@"name"];
    return @"";
}

-(CIImage*) outputImage {
    CIImage * _outputImage;
    if(transitionTime >= 1){
        [self willChangeValueForKey:@"out1selected"];
		[self willChangeValueForKey:@"out2selected"];
        [self willChangeValueForKey:@"out3selected"];
        
        transitionImageSourceSelector = self.outSelector;
        transitionTime = -1;
        
        [self didChangeValueForKey:@"out1selected"];
		[self didChangeValueForKey:@"out2selected"];
        [self didChangeValueForKey:@"out3selected"];
        
    }
    
    
    if(self.fadeTime > 0 && transitionTime != -1){
        if(transitionTime == 0){
            [self updateTransitionTime];
            //            [self performSelector:@selector(updateTransitionTime) withObject:nil afterDelay:0.1];
        }
        [self.dissolveFilter setValue:[self imageForSelector:transitionImageSourceSelector] forKey:@"inputImage"];
        [self.dissolveFilter setValue:[self imageForSelector:self.outSelector] forKey:@"inputTargetImage"];
        
        [self.dissolveFilter setValue:@(transitionTime) forKey:@"inputTime"];
        _outputImage = [self.dissolveFilter valueForKey:@"outputImage"];
        
    } else {
        /* if(self.outSelector == 0){
         [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
         return [self.constantColorFilter valueForKey:@"outputImage"];
         }*/
        
        _outputImage = [self imageForSelector:self.outSelector];
        if(!_outputImage){
            return nil;
        }
        [self willChangeValueForKey:@"out1selected"];
		[self willChangeValueForKey:@"out2selected"];
        [self willChangeValueForKey:@"out3selected"];
        transitionImageSourceSelector = self.outSelector;
        [self didChangeValueForKey:@"out1selected"];
		[self didChangeValueForKey:@"out2selected"];
        [self didChangeValueForKey:@"out3selected"];
        
        
        if(self.outSelector == 0){
            return  _outputImage;
        }
        /*        if(self.outSelector > 0 && self.outSelector <= 3){
         _outputImage = cameras[self.outSelector-1];
         }*/
    }
    

    
    [self.perspectiveFilter setValue:_outputImage forKey:@"inputImage"];
    _outputImage = [self.perspectiveFilter valueForKey:@"outputImage"];
    

    
    
    //----
    
    
    [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] forKey:@"inputColor"];
    [self.sourceOverFilter setValue: _outputImage forKey:@"inputImage"];
    [self.sourceOverFilter setValue:[self.constantColorFilter valueForKey:@"outputImage"] forKey:@"inputBackgroundImage"];
    _outputImage = [self.sourceOverFilter valueForKey:@"outputImage"];
    
    
    
    //----
    
    [self.constantColorFilter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1-self.master] forKey:@"inputColor"];
    
    [self.sourceOverFilter setValue:_outputImage forKey:@"inputBackgroundImage"];
    [self.sourceOverFilter setValue:[self.constantColorFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    _outputImage = [self.sourceOverFilter valueForKey:@"outputImage"];
    
    

    
    
    return _outputImage;
}


-(void) updateChromeFilter{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    float chromaMin = [defaults floatForKey:@"chromaMin"];
    float chromaMax = [defaults floatForKey:@"chromaMax"];
    float chromaVal = [defaults floatForKey:@"chromaVal"];
    float chromaSat = [defaults floatForKey:@"chromaSat"];
    
    float chromaBlur = [defaults floatForKey:@"chromaBlur"];
    float chromaBlur2 = [defaults floatForKey:@"chromaBlur2"];
    
    if(chromaMin != chromaMinSet || chromaMax != chromaMaxSet || chromaSat != chromaSatSet || chromaVal != chromaValSet){
        chromaMinSet = chromaMin;
        chromaMaxSet = chromaMax;
        chromaSatSet = chromaSat;
        chromaValSet = chromaVal;
        [self.chromaFilter setMinHueAngle:chromaMinSet maxHueAngle:chromaMaxSet minValue:chromaVal minSaturation:chromaSat];
    }
    
    [self.chromaFilter setGaussianRadius:chromaBlur  setGaussianRadius2:chromaBlur2 noiseReduction:[[defaults valueForKey:@"noiseReduction"] floatValue]];
    

}

-(CIImage*) chromaKey:(CIImage*)image backgroundImage:(CIImage*)background{
    [self updateChromeFilter];
    self.chromaFilter.inputBackgroundImage = background;
    self.chromaFilter.inputImage = image;
    return [self.chromaFilter outputImage];
}

-(CIImage*) filterCIImage:(CIImage*)inputImage{
    if(inputImage != nil){
    __block CIImage * _outputImage = inputImage;
    
    [self.deinterlaceFilter setInputImage:_outputImage];
    _outputImage = [self.deinterlaceFilter valueForKey:@"outputImage"];
    
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
//    [self.noiseReductionFilter setValue:[defaults valueForKey:@"noiseReduction"] forKey:@"inputNoiseLevel"];
//    [self.noiseReductionFilter setValue:[defaults valueForKey:@"sharpness"] forKey:@"inputSharpness"];
//    [self.noiseReductionFilter setValue:_outputImage forKey:@"inputImage"];
//    _outputImage = [self.noiseReductionFilter valueForKey:@"outputImage"];
    
    
    [self.colorControlsFilter setValue:[defaults valueForKey:@"saturation"] forKey:@"inputSaturation"];
    /*[self.colorControlsFilter setValue:[NSNumber numberWithFloat:PropF(@"contrast")] forKey:@"inputContrast"];
     [self.colorControlsFilter setValue:[NSNumber numberWithFloat:PropF(@"brightness")] forKey:@"inputBrightness"];*/
    [self.colorControlsFilter setValue:_outputImage forKey:@"inputImage"];
    _outputImage = [self.colorControlsFilter valueForKey:@"outputImage"];
    
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
    } else {
        return nil;
    }
}

void MyPixelBufferReleaseCallback(void *releaseRefCon, const void *baseAddress){
 //   NSLog(@" release %i",baseAddress);
    delete (unsigned char*)baseAddress;
}

-(CVPixelBufferRef) createCVImageBufferFromCallback:(DecklinkCallback*)callback{
    int w = callback->w;
    int h = callback->h;
  //  unsigned char * bytes = callback->bytes;
    unsigned char * bytes = (unsigned char * ) malloc(callback->w*callback->h*4 * sizeof(unsigned char)) ;
    memcpy(bytes, callback->bytes, callback->w*callback->h*4);
//    NSLog(@" create %i",bytes);

    
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    
    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, w, h, k32ARGBPixelFormat, bytes, 4*w, (CVPixelBufferReleaseBytesCallback )MyPixelBufferReleaseCallback, (void*)bytes, (__bridge CFDictionaryRef)d, &buffer);
    
    return buffer;
}

static void MyMIDIReadProc(const MIDIPacketList *pklist, void *refCon, void *connRefCon){
    AppDelegate * ad = (__bridge AppDelegate*)refCon;
    
    MIDIPacket * packet = (MIDIPacket*)pklist->packet;
    
    for (int i = 0; i < pklist->numPackets; ++i) {
        for (int j = 0; j < packet->length; j+=3) {
            
            
            Byte midiCommand = packet->data[0+j] >> 4;
            
            if(midiCommand==11){//CC
                int channel = (packet->data[0+j] & 0xF) + 1;
                int number = packet->data[1+j] & 0x7F;
                int value = packet->data[2+j] & 0x7F;
                //      NSLog(@"%i %i %i",channel, number, value);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(channel == 1 && number == 1){
                        ad.fadeTime = value / 128.0;
                    }
                    if(channel == 1 && number == 0){
                        ad.master = value / 128.0;
                    }
                    
                    
                    if(channel == 2){
                        if(number == 0){
                            ad.outSelector = value;
                        }
                        
                        if(number == 1){
                            ad.decklink1input = value-1;
                        }
                        if(number == 2){
                            ad.decklink2input = value-1;
                        }
                        if(number == 3){
                            ad.decklink3input = value-1;
                        }
                    }
                    
                    if (channel == 3) {
                        if(number == 0){
                            [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"chromaKey"];
                        }
                    }
                });
                //        if()
            }
        }
        
        packet = MIDIPacketNext(packet);
    }
}

void MyMIDINotifyProc( const MIDINotification *message, void*refCon){
    
}




@end
