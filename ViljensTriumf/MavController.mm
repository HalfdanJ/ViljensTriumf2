//
//  MavController.m
//  ViljensTriumf
//
//  Created by Jonas on 10/9/12.
//
//

#import "MavController.h"

@implementation MavController

- (id)init
{
    self = [super init];
    if (self) {
        //connected=  serial.setup("/dev/tty.usbserial-FT5CHURVA", 9600);
        
        
        serialFileDescriptor = -1;
        waitingForData = NO;
        readThreadRunning = FALSE;
        incommingString = [NSMutableString string];
        NSString * serialPort = @"/dev/tty.usbserial-FT5CHURVA";

        
    /*    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:@"/dev/"];
        NSString *file;
        while (file = [enumerator nextObject])
        {
            //NSLog(@"%@",file);
            
            if([file rangeOfString:@"tty.usbmodem"].location != NSNotFound){
                serialPort = [NSString stringWithFormat:@"/dev/%@",file];
            }
            
//                    BOOL isDirectory=NO;
//             [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",@"/Applications",file] isDirectory:&isDirectory];
//             if (!isDirectory)
//             count++;
        }
        
        //    NSString *error = [self openSerialPort:@"/dev/tty.usbserial-AH00SB3J" baud:BAUDRATE];
        //    NSString *error = [self openSerialPort:@"/dev/tty.usbserial-A70064SC" baud:BAUDRATE];
        if(!serialPort){
            [appDelegate logError:@"Serial not found"];
            
            return;
        }*/
        
        NSString *error = [self openSerialPort:serialPort baud:BAUDRATE];
        
        //        NSString *error = [self openSerialPort:@"/dev/tty.usbmodem26211" baud:BAUDRATE];
        if(error != nil){
            NSLog(@"Open MAV Serial error: %@",error);
            connected = NO;
            
        } else {
            NSLog(@"MAV Serial successfully opened");
            connected = YES;
            
            [self performSelectorInBackground:@selector(serialReadThread:) withObject:[NSThread currentThread]];
            //[self performSelectorInBackground:@selector(serialUpdateThread:) withObject:[NSThread currentThread]];
            
        }
        
        NSMutableArray * arr =  [NSMutableArray array];
        for(int i=0;i<16;i++){
            NSMutableDictionary * dict = [@{@"input":@(1)} mutableCopy];
            [dict addObserver:self forKeyPath:@"input" options:0 context:(void*)@(i+1)];
            [arr addObject:dict];
        }
        self.outputPatch = arr;
        
        
    }
    return self;
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    int output = [(__bridge NSNumber*)context intValue];
    int input = [[object valueForKey:@"input"] intValue]+1;
    
    if(input != 0){
        NSLog(@"Change observe %i %i",input, output) ;
        [self patchInput:input toOutput:output];
    }
}

-(void) patchInput:(int)input toOutput:(int)output{
    [self writeString:[NSString stringWithFormat:@"%i*%i!",input,output]];
}

/*-(void) update {
    if(connected	){
        while(serial.available()){
            incommingBytes[incommingBytesIndex++] = serial.readByte();
            if(incommingBytes[incommingBytesIndex-1] == '\n'){
                incommingBytesIndex = 0;
                NSString * incommingStr = [NSString stringWithUTF8String:incommingBytes];
                NSLog(@"Got msg: %@",incommingStr);
                
                if([incommingStr rangeOfString:@"RECONFIG"].location != NSNotFound){
                    NSLog(@"Reconfig");
                    
                    serial.writeByte('v');
                    serial.writeByte('1');
                    serial.writeByte('%');
                }  else {
                    NSError *error = NULL;
                    NSRegularExpression *regex = [NSRegularExpression
                                                  regularExpressionWithPattern:@"OUT+%i+%i IN+%i+%i VID"
                                                  options:NSRegularExpressionCaseInsensitive
                                                  error:&error];
                    [regex enumerateMatchesInString:incommingStr options:0 range:NSMakeRange(0, [incommingStr length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
                        // your code to handle matches here
                        NSLog(@"Match %@",match);
                    }];
                }
                
                memset(incommingBytes,0,sizeof(incommingBytes));
            }
        }
    }
}*/

-(void) receiveMessage:(NSString*)msg{
    NSLog(@"Recv %@",msg);
    if([msg rangeOfString:@"RECONFIG"].location != NSNotFound){
        [self readAllOutputs];
    }
    for(int i=0;i<16;i++){
        NSString * outStr = [NSString stringWithFormat:@"0%i",i+1];
        if(i >= 9)
            outStr = [NSString stringWithFormat:@"%i",i+1];
        if([msg rangeOfString:[NSString stringWithFormat:@"Out%@ In",outStr]].location != NSNotFound && [msg rangeOfString:@" Vid"].location != NSNotFound){
            int inVal = [[msg substringWithRange:NSMakeRange(8, 2)] intValue];
            
            if([[self.outputPatch[i] valueForKey:@"input"] intValue] != inVal-1){
                NSLog(@"Found change %@ = %i",outStr, inVal);

                [self.outputPatch[i] setValue:@(inVal-1) forKey:@"input"];
            }
            
        }
    }

}


-(void) readAllOutputs{
    dispatch_async(dispatch_queue_create("com.mycompany.myqueue", 0), ^{
        for(int i=0;i<16;i++){
            [self writeString:[NSString stringWithFormat:@"v%i%%", i+1]];
            [NSThread sleepForTimeInterval:0.01];
        }
    });
 }

-(void) writeString:(NSString *)str{
    [self writeBytes:(char*)[str cStringUsingEncoding:NSUTF8StringEncoding] length:int([str length])];
}
-(void)writeBytes:(char *)bytes length:(int)length{
    if(serialFileDescriptor != -1){
        write(serialFileDescriptor, bytes, length);
    }
}

// This selector will be called as another thread
- (void)serialReadThread: (NSThread *) parentThread {
    @autoreleasepool {
        
        readThreadRunning = TRUE;
        
        const int BUFFER_SIZE = 100;
        unsigned char byte_buffer[BUFFER_SIZE]; // buffer for holding incoming data
        ssize_t numBytes=0; // number of bytes read during read
        NSString *text; // incoming text from the serial port
        
        // assign a high priority to this thread
        [NSThread setThreadPriority:0.5];
        
        // this will loop unitl the serial port closes
        while(TRUE) {
            // read() blocks until some data is available or the port is closed
            numBytes = read(serialFileDescriptor, byte_buffer, BUFFER_SIZE); // read up to the size of the buffer
            if(numBytes>0) {
                @synchronized(self){
                    
                    for(int i=0;i<numBytes;i++){
                        unsigned char c = byte_buffer[i];
                        if(c == '\n'){
                            [self receiveMessage:incommingString];
                            [incommingString setString:@""];
                        } else {
                            [incommingString appendFormat:@"%c",c];
                        }
                    }
                }
            }
        }
        // make sure the serial port is closed
        if (serialFileDescriptor != -1) {
            close(serialFileDescriptor);
            serialFileDescriptor = -1;
        }
        
        // mark that the thread has quit
        readThreadRunning = FALSE;
        
        // give back the pool
    }
}


- (NSString *) openSerialPort: (NSString *)serialPortFile baud: (speed_t)baudRate {
	int success = 0;
	
	// close the port if it is already open
	if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
		
		// wait for the reading thread to die
		while(readThreadRunning);
		
		// re-opening the same port REALLY fast will fail spectacularly... better to sleep a sec
		sleep(0.5);
	}
	
	// c-string path to serial-port file
	const char *bsdPath = [serialPortFile cStringUsingEncoding:NSUTF8StringEncoding];
	
	// Hold the original termios attributes we are setting
	struct termios options;
	
	// receive latency ( in microseconds )
	unsigned long mics = 3;
	
	// error message string
	NSString *errorMessage = nil;
	
	// open the port
	//     O_NONBLOCK causes the port to open without any delay (we'll block with another call)
	serialFileDescriptor = open(bsdPath, O_RDWR | O_NOCTTY | O_NONBLOCK );
    
    if(serialFileDescriptor == -1){
        // ofLog(OF_LOG_ERROR,"ofSerial: unable to open port %s", portName.c_str());
        errorMessage = @"XBee not found";
        return errorMessage;
    }
    
    //struct termios options;
    tcgetattr(serialFileDescriptor,&gOriginalTTYAttrs);
    options = gOriginalTTYAttrs;
    switch(baudRate){
        case 300: 	cfsetispeed(&options,B300);
            cfsetospeed(&options,B300);
            break;
        case 1200: 	cfsetispeed(&options,B1200);
            cfsetospeed(&options,B1200);
            break;
        case 2400: 	cfsetispeed(&options,B2400);
            cfsetospeed(&options,B2400);
            break;
        case 4800: 	cfsetispeed(&options,B4800);
            cfsetospeed(&options,B4800);
            break;
        case 9600: 	cfsetispeed(&options,B9600);
            cfsetospeed(&options,B9600);
            break;
        case 14400: 	cfsetispeed(&options,B14400);
            cfsetospeed(&options,B14400);
            break;
        case 19200: 	cfsetispeed(&options,B19200);
            cfsetospeed(&options,B19200);
            break;
        case 28800: 	cfsetispeed(&options,B28800);
            cfsetospeed(&options,B28800);
            break;
        case 38400: 	cfsetispeed(&options,B38400);
            cfsetospeed(&options,B38400);
            break;
        case 57600:  cfsetispeed(&options,B57600);
            cfsetospeed(&options,B57600);
            break;
        case 115200: cfsetispeed(&options,B115200);
            cfsetospeed(&options,B115200);
            break;
            
        default:	cfsetispeed(&options,B9600);
            cfsetospeed(&options,B9600);
            //ofLog(OF_LOG_ERROR,"ofSerialInit: cannot set %i baud setting baud to 9600\n", baud);
            break;
    }
    
    options.c_cflag |= (CLOCAL | CREAD);
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;
    //    options.c_cflag |= CRTSCTS;                              /*enable RTS/CTS flow control - linux only supports rts/cts*/
    //  options.c_cflag |= PARENB;
    
    
    tcsetattr(serialFileDescriptor,TCSANOW,&options);
    
    // make sure the port is closed if a problem happens
	if ((serialFileDescriptor != -1) && (errorMessage != nil)) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
	}
	
	return errorMessage;
}


@end

