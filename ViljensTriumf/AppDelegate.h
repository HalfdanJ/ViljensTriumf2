//
//  AppDelegate.h
//  ViljensTriumf
//
//  Created by Jonas on 10/10/12.
//  Copyright (c) 2012 Jonas. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

#import "BlackMagicController.h"
#import "CoreImageViewer.h"

#import "DecklinkCallback.h"

#import "ChromaFilter.h"
#import "DeinterlaceFilter.h"
#import "MavController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
@public
    CIImage * cameras[3];
    float chromaMinSet, chromaMaxSet;
    bool _recording;
    bool _playVideo;
    
    NSImage * recordImage;
//    CVOpenGLTextureRef  movieCurrentFrame;
  //  QTVisualContextRef	movieTextureContext;
    
    //Movie recording
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* videoWriterInput ;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    
    AVQueuePlayer * avPlayer;
    AVPlayerLayer * avPlayerLayer;

    
    AVPlayer * avPlayerPreview;
    AVPlayerLayer * avPlayerLayerPreview;
    
    id avPlayerBoundaryPreview;
    id avPlayerBoundary;
    
    float transitionTime;
    int transitionImageSourceSelector;
}

@property (unsafe_unretained) IBOutlet NSWindow *mainOutputWindow;
@property (assign) IBOutlet NSWindow *window;
@property (strong) BlackMagicController * blackMagicController;
@property (weak) IBOutlet CoreImageViewer *preview1;
@property (weak) IBOutlet CoreImageViewer *preview2;
@property (weak) IBOutlet CoreImageViewer *preview3;
@property (weak) IBOutlet CoreImageViewer *mainOutput;
@property (weak) IBOutlet NSView *videoView;

@property (strong) DeinterlaceFilter * deinterlaceFilter;
@property (strong) CIFilter * colorControlsFilter;
@property (strong) CIFilter * gammaAdjustFilter;
@property (strong) CIFilter * toneCurveFilter;
@property (strong) ChromaFilter * chromaFilter;
@property (strong) CIFilter * dissolveFilter;
@property (strong) CIFilter * sourceOverFilter;
@property (strong) CIFilter * constantColorFilter;
@property (strong) CIFilter * widescreenFilter;
@property (strong) CIFilter * dslrFilter;


@property (readwrite) int outSelector;

@property (readwrite) float master;
@property (readwrite) float fadeTime;

//@property (strong) QTMovie * mMovie;
@property (readwrite) NSTimeInterval startRecordTime;
@property (readwrite) bool recording;
@property (readwrite) int recordingIndex;
@property (weak) IBOutlet NSArrayController *recordingsArrayController;
@property (readwrite) bool playVideo;
@property (strong) NSMutableArray * recordings;
@property (readwrite) bool readyToRecord;

@property (strong) MavController * mavController;
@property (strong) NSMutableArray * cameraInputs;
@property (readwrite) int decklink1input;
@property (readwrite) int decklink2input;
@property (readwrite) int decklink3input;

-(void) newFrame:(DecklinkCallback*)callback;

@end
