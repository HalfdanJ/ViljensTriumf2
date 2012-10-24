//
//  ChromaFilter.m
//  ViljensTriumf
//
//  Created by Jonas on 10/9/12.
//
//

#import "ChromaFilter.h"

typedef struct {
    double r;       // percent
    double g;       // percent
    double b;       // percent
} rgb;

typedef struct {
    double h;       // angle in degrees
    double s;       // percent
    double v;       // percent
} hsv;


void rgb2hsv(float * rgb, float * hsv)
{
    double      min, max, delta;
    
    min = rgb[0] < rgb[1] ? rgb[0] : rgb[1];
    min = min  < rgb[2] ? min  : rgb[2];
    
    max = rgb[0] > rgb[1] ? rgb[0] : rgb[1];
    max = max  > rgb[2] ? max  : rgb[2];
    
    hsv[2] = max;                                // v
    delta = max - min;
    if( max > 0.0 ) {
        hsv[1] = (delta / max);                  // s
    } else {
        // r = g = b = 0                        // s = 0, v is undefined
        hsv[1] = 0.0;
        hsv[0] = NAN;                            // its now undefined
        return;
    }
    if( rgb[0] >= max )                           // > is bogus, just keeps compilor happy
        hsv[0] = ( rgb[1] - rgb[2] ) / delta;        // between yellow & magenta
    else
        if( rgb[1] >= max )
            hsv[0] = 2.0 + ( rgb[2] - rgb[0] ) / delta;  // between cyan & yellow
        else
            hsv[0] = 4.0 + ( rgb[0] - rgb[1] ) / delta;  // between magenta & cyan
    
    hsv[0] *= 60.0;                              // degrees
    
    if( hsv[0] < 0.0 )
        hsv[0] += 360.0;
    
}


static CIKernel *alphaOverKernel = nil;
static CIKernel *alphaThresholdKernel = nil;

@implementation ChromaFilter
@synthesize inputImage = _inputImage;
@synthesize inputBackgroundImage = _inputBackgroundImage;
//@synthesize inputForegroundImage = _inputForegroundImage;

static dispatch_once_t onceToken;
static CIFilter *colorCube;
static CIFilter * gaussianFilter;
static CIFilter * gaussianFilter2;
static CIFilter * noiseReductionFilter;
static CIFilter * scaleFilter;

- (id)init
{
   self = [super init];
    //sourceOverFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];

    dispatch_once(&onceToken, ^{
        
        colorCube = [CIFilter filterWithName:@"CIColorCube"];
        
        
        if(alphaOverKernel == nil)// 1
        {
            NSBundle    *bundle = [NSBundle bundleForClass: [self class]];// 2
            NSString    *code = [NSString stringWithContentsOfFile: [bundle// 3
                                                                     pathForResource: @"alphaOver"
                                                                     ofType: @"cikernel"]];
            NSArray     *kernels = [CIKernel kernelsWithString: code];// 4
            alphaOverKernel = [kernels objectAtIndex:0];// 5
            
            alphaThresholdKernel = [kernels objectAtIndex:1];// 5
            
        }
        
        
        gaussianFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [gaussianFilter setDefaults];

        gaussianFilter2 = [CIFilter filterWithName:@"CIGaussianBlur"];
        [gaussianFilter2 setDefaults];
        
        noiseReductionFilter = [CIFilter filterWithName:@"CINoiseReduction"] ;
        [noiseReductionFilter setDefaults];
        
        scaleFilter = [CIFilter filterWithName:@"CIAffineTransform"];
        [scaleFilter setDefaults];

    });


    return self;
}

-(void) setMinHueAngle:(float)minHueAngle maxHueAngle:(float)maxHueAngle minValue:(float)minValue minSaturation:(float)minSaturation{
    
    
    // Allocate memory
    const unsigned int size = 64;
    int cubeDataSize = size * size * size * sizeof (float) * 4;
    float *cubeData = (float *)malloc (cubeDataSize);
    float rgb[4], hsv[3], *c = cubeData;
    
    // Populate cube with a simple gradient going from 0 to 1
    for (int z = 0; z < size; z++){
        rgb[2] = ((double)z)/(size-1); // Blue value
        for (int y = 0; y < size; y++){
            rgb[1] = ((double)y)/(size-1); // Green value
            for (int x = 0; x < size; x ++){
                rgb[0] = ((double)x)/(size-1); // Red value
                // Convert RGB to HSV
                // You can find publicly available rgbToHSV functions on the Internet
                rgb2hsv(rgb,hsv);
                
                // Use the hue value to determine which to make transparent
                // The minimum and maximum hue angle depends on
                // the color you want to remove
               
             //   printf("%f %f %f = %f\n",rgb[0], rgb[1], rgb[2], hsv[0]);
                float alpha = 1.0;
                if(hsv[0] > minHueAngle && hsv[0] < maxHueAngle && hsv[1] > minSaturation && hsv[2] > minValue)
                    alpha = 0;
                
/*                float hueWidth = 10;
                if(hsv[0] > minHueAngle - hueWidth && hsv[0] < minHueAngle + 10){
                    float i = (hsv[0]-minHueAngle-hueWidth)/(hueWidth*2.0);
                    alpha *= 1-i;
                } else if(hsv[0] > minHueAngle && hsv[0] < maxHueAngle){
                    alpha *= 0;
                }
*/
                
                // Calculate premultiplied alpha values for the cube
                c[0] = rgb[0] * alpha;
                c[1] = rgb[1] * alpha;
                c[2] = rgb[2] * alpha;
                c[3] = 1.0 * alpha;
                
                c += 4;
            }
        }
    }
    // Create memory with the cube data
    NSData *data = [NSData dataWithBytesNoCopy:cubeData
                                        length:cubeDataSize
                                  freeWhenDone:YES];
    [colorCube setValue:[NSNumber numberWithInt:size] forKey:@"inputCubeDimension"];
    // Set data for cube
    [colorCube setValue:data forKey:@"inputCubeData"];
}

-(NSArray *)inputKeys{
    return @[@"inputImage", @"inputBackgroundImage"];
}

-(void) setGaussianRadius:(float)radius setGaussianRadius2:(float)radius2 noiseReduction:(float)noiseReduction{
    [gaussianFilter setValue:@(radius) forKey:@"inputRadius"];
    [gaussianFilter2 setValue:@(radius2) forKey:@"inputRadius"];
    [noiseReductionFilter setValue:@(noiseReduction) forKey:@"inputNoiseLevel"];
}

- (CIImage *)outputImage
{
    if(self.inputImage == nil  || self.inputBackgroundImage == nil){
        NSLog(@"No image");
        return nil;
    }
  //  return self.inputBackgroundImage;
    
    CIImage * image = self.inputImage ;

    [noiseReductionFilter setValue:image forKey:@"inputImage"];
    image =[noiseReductionFilter valueForKey:@"outputImage"];
   
    [gaussianFilter setValue:image forKey:@"inputImage"];
    image = [gaussianFilter valueForKey:@"outputImage"];

    
    [colorCube setValue:image forKey:@"inputImage"];
    image = [colorCube valueForKey:@"outputImage"];
    
//    NSLog(@"%i",[[colorCube valueForKey:@"inputCubeDimension"] intValue]);

 //   return image;
  /*
    [sourceOverFilter setValue:[colorCube valueForKey:@"outputImage"] forKey:@"inputImage"];
    [sourceOverFilter setValue:self.inputBackgroundImage forKey:@"inputBackgroundImage"];
    
    
    return [sourceOverFilter valueForKey:@"outputImage"];

*/
    
/*    NSAffineTransform * transform = [NSAffineTransform transform];
    [transform scaleBy:self.inputImage.extent.size.width / self.inputBackgroundImage.extent.size.width];
    [scaleFilter setValue:transform forKey:@"inputTransform"];


    
    [scaleFilter setValue:image forKeyPath:@"inputImage"];
    image = [scaleFilter valueForKey:@"outputImage"];
  */  
//    NSLog(@" %f   %f", self.inputImage.extent.size.width,self.inputBackgroundImage.extent.size.width);
    if(image == nil){
        NSLog(@"No alpha image");
    }
    CISampler *alpha = [CISampler samplerWithImage: image];
    image = [self apply: alphaThresholdKernel, alpha, kCIApplyOptionDefinition, [alpha definition], nil];

    [gaussianFilter2 setValue:image forKey:@"inputImage"];
    image = [gaussianFilter2 valueForKey:@"outputImage"];

    
    CISampler *foreground = [CISampler samplerWithImage: self.inputImage];
    CISampler *background = [CISampler samplerWithImage: self.inputBackgroundImage];
    alpha = [CISampler samplerWithImage: image];
    // NSAssert(src, @" Nor Src");
    
    return [self apply: alphaOverKernel, foreground, alpha, background, kCIApplyOptionDefinition, [foreground definition], nil];

}

@end
