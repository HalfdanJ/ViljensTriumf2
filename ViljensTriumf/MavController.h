//
//  MavController.h
//  ViljensTriumf
//
//  Created by Jonas on 10/9/12.
//
//

#import <Cocoa/Cocoa.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>
#include <time.h>

#define BAUDRATE 9600

@interface MavController : NSObject
{
    bool connected;
    
    char incommingBytes[100];
    int incommingBytesIndex;
    
    NSMutableArray * outputs;
    
    
    int serialFileDescriptor;
    struct termios gOriginalTTYAttrs; // Hold the original termios attributes so we can reset them on quit ( best practice )
	bool readThreadRunning;
    
    unsigned char outputBuffer[127];
    int outputBufferCounter;


    BOOL waitingForData;
    NSMutableString * incommingString;
}

-(void) update;

- (NSString *) openSerialPort: (NSString *)serialPortFile baud: (speed_t)baudRate;
- (void) serialReadThread: (NSThread *) parentThread;
- (void) serialUpdateThread: (NSThread *) parentThread;
- (void) writeString: (NSString *) str;
- (void) writeByte: (unsigned char) val;
- (void) writeBuffer;
- (void) writeBytes: (unsigned char * ) bytes length:(int)length;
- (void) bufferBytes: (unsigned char * ) bytes length:(int)length;

@end
