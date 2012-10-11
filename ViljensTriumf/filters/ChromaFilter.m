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


@implementation ChromaFilter
@synthesize inputImage = _inputImage;
@synthesize backgroundImage = _backgroundImage;


- (id)init
{
   self = [super init];
    colorCube = [CIFilter filterWithName:@"CIColorCube"];
    sourceOverFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    
    return self;
}

-(void) setMinHueAngle:(float)minHueAngle maxHueAngle:(float)maxHueAngle{
    
    
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
                float alpha = (hsv[0] > minHueAngle && hsv[0] < maxHueAngle) ? 0.0f: 1.0f;
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


- (CIImage *)outputImage
{
    if(self.inputImage == nil)
        return nil;
    [colorCube setValue:self.inputImage forKey:@"inputImage"];
    
    [sourceOverFilter setValue:[colorCube valueForKey:@"outputImage"] forKey:@"inputImage"];
    [sourceOverFilter setValue:self.backgroundImage forKey:@"inputBackgroundImage"];
    
    
    return [sourceOverFilter valueForKey:@"outputImage"];
}

@end
