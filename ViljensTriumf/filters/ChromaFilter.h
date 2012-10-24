//
//  ChromaFilter.h
//  ViljensTriumf
//
//  Created by Jonas on 10/9/12.
//
//

#import <QuartzCore/QuartzCore.h>

@interface ChromaFilter : CIFilter{
    CIImage   * _inputImage;
//    CIImage   * _inputForegroundImage;
    CIImage   * _inputBackgroundImage;
    CIFilter * sourceOverFilter;
}

@property (strong) CIImage   *inputImage;
//@property (strong) CIImage   *inputForegroundImage;
@property (strong) CIImage   *inputBackgroundImage;



-(void) setMinHueAngle:(float)minHueAngle maxHueAngle:(float)maxHueAngle minValue:(float)minValue minSaturation:(float)minSaturation;
-(CIImage*)outputImage;
-(void) setGaussianRadius:(float)radius setGaussianRadius2:(float)radius2 noiseReduction:(float)noiseReduction;
@end
