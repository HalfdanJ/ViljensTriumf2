//
//  BlackMagicController.m
//  ViljensTriumf
//
//  Created by Jonas Jongejan on 05/10/12.
//
//

#import "BlackMagicController.h"

@implementation BlackMagicController

-(void) initDecklink {
    IDeckLinkIterator*	deckLinkIterator = NULL;
	IDeckLink*			deckLink = NULL;
    IDeckLinkDisplayModeIterator*	displayModeIterator = NULL;
    
    IDeckLinkDisplayMode*			displayMode = NULL;
	bool				result = false;
    std::vector<IDeckLinkDisplayMode*>	modeList;
    
    callbacks[0] = new DecklinkCallback();
    callbacks[1] = new DecklinkCallback();
    callbacks[2] = new DecklinkCallback();
	
	// Create an iterator
	deckLinkIterator = CreateDeckLinkIteratorInstance();
	
	if(deckLinkIterator){
        // List all DeckLink devices
        while (deckLinkIterator->Next(&deckLink) == S_OK)
        {
            // Add device to the device list
            deviceList.push_back(deckLink);
            
            
        }
        
        glhelper = CreateOpenGLScreenPreviewHelper();
        
        for(int index=0;index<deviceList.size();index++){
            // Get the IDeckLinkInput for the selected device
            if ((deviceList[index]->QueryInterface(IID_IDeckLinkInput, (void**)&deckLinkInputs[index]) != S_OK))
            {
                NSLog(@"This application was unable to obtain IDeckLinkInput for the selected device.");
            }
            
            if ((deviceList[index]->QueryInterface(IID_IDeckLinkOutput, (void**)&deckLinkOutputs[index]) != S_OK))
            {
                NSLog(@"This application was unable to obtain IDeckLinkOutput for the selected device.");
            }
            
            
            //
            // Retrieve and cache mode list
            if (deckLinkInputs[index]->GetDisplayModeIterator(&displayModeIterator) == S_OK)
            {
                CFStringRef			modeName;
                int i=0;
                
                while (displayModeIterator->Next(&displayMode) == S_OK){
                    modeList.push_back(displayMode);
                    
                    if (displayMode->GetName(&modeName) == S_OK)
                    {
                        NSLog(@"Mode: %i %@",i++,(__bridge NSString *)modeName);
                    }
                }
                
                displayModeIterator->Release();
            }
            
            
            
            
            // Set capture callback
            BMDVideoInputFlags		videoInputFlags = bmdVideoInputFlagDefault;
            
            deckLinkInputs[index]->SetCallback(callbacks[index]);
            
            callbacks[index]->decklinkOutput = deckLinkOutputs[index];
            
            
            // Set the video input mode
            if (deckLinkInputs[index]->EnableVideoInput(modeList[2]->GetDisplayMode(), bmdFormat8BitYUV, videoInputFlags) != S_OK)
            {
                /*  [uiDelegate showErrorMessage:@"This application was unable to select the chosen video mode. Perhaps, the selected device is currently in-use." title:@"Error starting the capture"];
                 return false;*/
                NSLog(@"This application was unable to select the chosen video mode. Perhaps, the selected device is currently in-use.");
            }
            
            HRESULT				theResult;
            // Turn on video output
            theResult = deckLinkOutputs[index]->EnableVideoOutput(modeList[2]->GetDisplayMode(), bmdVideoOutputFlagDefault);
            if (theResult != S_OK)
                printf("EnableVideoOutput failed with result %08x\n", (unsigned int)theResult);
            //
            theResult = deckLinkOutputs[index]->StartScheduledPlayback(0, 600, 1.0);
            if (theResult != S_OK)
                printf("StartScheduledPlayback failed with result %08x\n", (unsigned int)theResult);
            
            
            
            // Start the capture
            if (deckLinkInputs[index]->StartStreams() != S_OK)
            {
                NSLog(@"This application was unable to start the capture. Perhaps, the selected device is currently in-use.");
                /*  [uiDelegate showErrorMessage:@"This application was unable to start the capture. Perhaps, the selected device is currently in-use." title:@"Error starting the capture"];
                 return false;*/
            }
            
            
            
        }
        
       // result = true;
	}

}

-(NSArray*)getDeviceNameList{
    NSMutableArray*		nameList = [NSMutableArray array];
	int					deviceIndex = 0;
	
	while (deviceIndex < deviceList.size())
	{
		CFStringRef	cfStrName;
		
		// Get the name of this device
		if (deviceList[deviceIndex]->GetDisplayName(&cfStrName) == S_OK)
		{
			[nameList addObject:(__bridge NSString *)cfStrName];
			CFRelease(cfStrName);
		}
		else
		{
			[nameList addObject:@"DeckLink"];
		}
        
		deviceIndex++;
	}
	
	return nameList;
}

-(DecklinkCallback *)callbacks:(int)num{
    return callbacks[num];
}
@end
