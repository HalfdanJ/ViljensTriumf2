//
//  DeinterlaceFilter.m
//  ViljensTriumf
//
//  Created by Jonas Jongejan on 05/10/12.
//
//

#import "DeinterlaceFilter.h"

static CIKernel *deinterlaceKernel = nil;

@implementation DeinterlaceFilter
@synthesize inputImage = _inputImage;

- (id)init
{
    if(deinterlaceKernel == nil)// 1
    {
        NSBundle    *bundle = [NSBundle bundleForClass: [self class]];// 2
        NSString    *code = [NSString stringWithContentsOfFile: [bundle// 3
                                                                 pathForResource: @"deinterlaceFilter"
                                                                 ofType: @"cikernel"]];
        NSArray     *kernels = [CIKernel kernelsWithString: code];// 4
        deinterlaceKernel = [kernels objectAtIndex:0];// 5
    }
    return [super init];
}

- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage: self.inputImage];
    
    return [self apply: deinterlaceKernel, src, kCIApplyOptionDefinition, [src definition], nil];
}


@end
