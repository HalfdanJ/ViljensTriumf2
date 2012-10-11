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
    CIImage   * _backgroundImage;
    CIFilter *colorCube;
    CIFilter * sourceOverFilter;
}

@property (strong) CIImage   *inputImage;
@property (strong) CIImage   *backgroundImage;

-(void) setMinHueAngle:(float)minHueAngle maxHueAngle:(float)maxHueAngle;
- (CIImage *)outputImage;

@end
