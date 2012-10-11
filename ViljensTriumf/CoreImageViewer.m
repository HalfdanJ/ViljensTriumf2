//
//  CoreImageViewer.m
//  ViljensTriumf
//
//  Created by Jonas on 10/9/12.
//
//

#import "CoreImageViewer.h"

@implementation CoreImageViewer

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    
    // [self.ciImage drawInRect:dirtyRect fromRect:NSRectFromCGRect([self.ciImage extent]) operation:  NSCompositeClear  fraction:1.0];
    @autoreleasepool {
        if(ciContext == nil){
            ciContext = [CIContext contextWithCGContext:
                         [[NSGraphicsContext currentContext] graphicsPort] options: nil];
        }
        [ciContext drawImage:self.ciImage inRect:NSRectToCGRect(dirtyRect) fromRect:NSMakeRect(0, 0, 720, 576)];
    }
    
}

@end
