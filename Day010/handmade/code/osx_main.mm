// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include "osx_main.h"

global_variable bool Running = true;

void MacRefreshBuffer(mac_offscreen_buffer *Buffer, NSWindow *Window) {

    if (Buffer->Memory) {
        free(Buffer->Memory);
    }

    Buffer->Width = Window.contentView.bounds.size.width;
    Buffer->Height = Window.contentView.bounds.size.height;
    Buffer->Pitch = Buffer->Width * Buffer->BytesPerPixel;
    Buffer->Memory = (uint8 *)malloc(Buffer->Pitch * Buffer->Height);
}

internal
void RenderWeirdGradient(mac_offscreen_buffer *Buffer, 
                         int OffsetX, int OffsetY) 
{ 

    uint8 *Row = (uint8 *)Buffer->Memory;

    for (int Y = 0; Y < Buffer->Height; ++Y) {

        uint8 *Pixel = (uint8 *)Row;

        for(int X = 0; X < Buffer->Width; ++X) {
            
            /*  Pixel in memory: RR GG BB AA */

            //Red            
            *Pixel = 0; 
            ++Pixel;  

            //Green
            *Pixel = (uint8)Y+(uint8)OffsetY;
            ++Pixel;

            //Blue
            *Pixel = (uint8)X+(uint8)OffsetX;
            ++Pixel;

            //Alpha
            *Pixel = 255;
            ++Pixel;          
        }

        Row += Buffer->Pitch;
    }

}

void MacRedrawBuffer(mac_offscreen_buffer *Buffer, NSWindow *Window) {
    @autoreleasepool {
        NSBitmapImageRep *Rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &Buffer->Memory
                                  pixelsWide: Buffer->Width
                                  pixelsHigh: Buffer->Height
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bytesPerRow: Buffer->Pitch
                                  bitsPerPixel: Buffer->BytesPerPixel * 8] autorelease];

        NSSize ImageSize = NSMakeSize(Buffer->Width, Buffer->Height);
        NSImage *Image = [[[NSImage alloc] initWithSize: ImageSize] autorelease];
        [Image addRepresentation: Rep];
        Window.contentView.layer.contents = Image;
    }
}

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 

- (void)windowWillClose:(id)sender {
    Running = false;  
}

@end

@interface KeyIgnoringWindow: NSWindow
@end

@implementation KeyIgnoringWindow
- (void)keyDown:(NSEvent *)theEvent { }
@end

internal
void ControllerInput(void *context, IOReturn result, 
                     void *sender, IOHIDValueRef value)
{

    if(result != kIOReturnSuccess) {
        return;
    }

    mac_game_controller *MacGameController = (mac_game_controller *)context;
    
    IOHIDElementRef Element = IOHIDValueGetElement(value);    
    uint32 UsagePage = IOHIDElementGetUsagePage(Element);
    uint32 Usage = IOHIDElementGetUsage(Element);

    //Buttons
    if(UsagePage == kHIDPage_Button) {
        // TODO: (ted)  Use our own Boolean type here?
        BOOL ButtonState = (BOOL)IOHIDValueGetIntegerValue(value);

        if (Usage == MacGameController->XButtonUsageID)
        {
            MacGameController->XButtonState = ButtonState;
        }
        else if (Usage == MacGameController->SquareButtonUsageID)
        {
            MacGameController->SquareButtonState = ButtonState;
        }
        else if (Usage == MacGameController->TriangleButtonUsageID)
        {
            MacGameController->TriangleButtonState = ButtonState;
        }
        else if (Usage == MacGameController->CircleButtonUsageID)
        {
            MacGameController->CircleButtonState = ButtonState;
        }
        else if (Usage == MacGameController->LeftShoulderButtonUsageID)
        {
            MacGameController->LeftShoulderButtonState = ButtonState;
        }
        else if (Usage == MacGameController->RightShoulderButtonUsageID)
        {
            MacGameController->RightShoulderButtonState = ButtonState;
        }
    }
    else if (UsagePage == kHIDPage_GenericDesktop)
    {
        double_t Analog = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated);

        // NOTE: (ted)  It seems like slamming the stick left gives me a value of zero 
        //              and slamming it all the way right gives a value of 255. 
        //
        //              I would gather this is being mapped to an eight bit unsigned integer

        //              Max Y up is zero. Max Y down is 255. Not moving Y is 128.
        if (Usage == MacGameController->LeftThumbXUsageID) {
            MacGameController->LeftThumbstickX = (real32)Analog;
        }

        if (Usage == MacGameController->LeftThumbYUsageID) {
            MacGameController->LeftThumbstickY = (real32)Analog;
        }

        if(Usage == kHIDUsage_GD_Hatswitch) { 
            int DPadState = (int)IOHIDValueGetIntegerValue(value);
            int32 DPadX = 0;
            int32 DPadY = 0;

            switch(DPadState) {
                case 0: DPadX = 0; DPadY = 1; break;
                case 1: DPadX = 1; DPadY = 1; break;
                case 2: DPadX = 1; DPadY = 0; break;
                case 3: DPadX = 1; DPadY = -1; break;
                case 4: DPadX = 0; DPadY = -1; break;
                case 5: DPadX = -1; DPadY = -1; break;
                case 6: DPadX = -1; DPadY = 0; break;
                case 7: DPadX = -1; DPadY = 1; break;
                default: DPadX = 0; DPadY = 0; break;
            }

            MacGameController->DPadX = DPadX;
            MacGameController->DPadY = DPadY;
        }
    }
}

internal 
void ControllerConnected(void *context, IOReturn result, 
                         void *sender, IOHIDDeviceRef device)
{
    if(result != kIOReturnSuccess) {
        return;
    }

    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                       CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                        CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];

    mac_game_controller *MacGameController = (mac_game_controller *)context;

    if(vendorID == 0x054C && productID == 0x5C4) {
        NSLog(@"Sony Dualshock 4 detected.");
        
        MacGameController->XButtonUsageID = 0x02;
        MacGameController->SquareButtonUsageID = 0x01;
        MacGameController->TriangleButtonUsageID = 0x04;
        MacGameController->CircleButtonUsageID = 0x03;
        MacGameController->LeftShoulderButtonUsageID = 0x05;
        MacGameController->RightShoulderButtonUsageID = 0x06;

        MacGameController->LeftThumbXUsageID = kHIDUsage_GD_X;
        MacGameController->LeftThumbYUsageID = kHIDUsage_GD_Y;
    }

    MacGameController->LeftThumbstickX = 128.0f;
    MacGameController->LeftThumbstickY = 128.0f;

    IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (void *)MacGameController);  

    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);
}

internal void
MacSetupGameController(mac_game_controller *MacGameController)
{
    IOHIDManagerRef HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);

    // TODO: (ted)  Actually handle errors better
    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, ControllerConnected, (void *)MacGameController);

    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
    ]);
  
	IOHIDManagerScheduleWithRunLoop(HIDManager, 
                                    CFRunLoopGetMain(), 
                                    kCFRunLoopDefaultMode);
}

internal void
MacHandleKeyboardEvent(mac_game_controller *GameController, NSEvent *Event)
{
    switch (Event.type) {
    case NSEventTypeKeyDown:
        if (Event.keyCode == UpArrowKeyCode)
        {
            GameController->DPadY = 1;
        }
        else if (Event.keyCode == DownArrowKeyCode)
        {
            GameController->DPadY = -1;
        }
        else if (Event.keyCode == LeftArrowKeyCode)
        {
            GameController->DPadX = 1;
        }
        else if (Event.keyCode == RightArrowKeyCode)
        {
            GameController->DPadX = -1;
        }
        else if (Event.keyCode == AKeyCode)
        {
            GameController->XButtonState = true;
        }
        else if (Event.keyCode == SKeyCode)
        {
            GameController->CircleButtonState = true;
        }
        else if (Event.keyCode == DKeyCode)
        {
            GameController->SquareButtonState = true;
        }
        else if (Event.keyCode == FKeyCode)
        {
            GameController->TriangleButtonState = true;
        }
        else if (Event.keyCode == QKeyCode)
        {
            GameController->LeftShoulderButtonState = true;
        }
        else if (Event.keyCode == RKeyCode)
        {
            GameController->RightShoulderButtonState = true;
        }

        break;
    case NSEventTypeKeyUp:
        if (Event.keyCode == UpArrowKeyCode || Event.keyCode == DownArrowKeyCode)
        {
            GameController->DPadY = 0;
        }
        else if (Event.keyCode == LeftArrowKeyCode || Event.keyCode == RightArrowKeyCode)
        {
            GameController->DPadX = 0;
        }
        else if (Event.keyCode == AKeyCode)
        {
            GameController->XButtonState = false;
        }
        else if (Event.keyCode == SKeyCode)
        {
            GameController->CircleButtonState = false;
        }
        else if (Event.keyCode == DKeyCode)
        {
            GameController->SquareButtonState = false;
        }
        else if (Event.keyCode == FKeyCode)
        {
            GameController->TriangleButtonState = false;
        }
        else if (Event.keyCode == QKeyCode)
        {
            GameController->LeftShoulderButtonState = false;
        }
        else if (Event.keyCode == RKeyCode)
        {
            GameController->RightShoulderButtonState = false;
        }
    }
}

internal OSStatus 
SquareWaveRenderCallback(void *inRefCon,
                         AudioUnitRenderActionFlags *ioActionFlags,
                         const AudioTimeStamp *inTimeStamp,
                         uint32 inBusNumber,
                         uint32 inNumberFrames,
                         AudioBufferList *ioData) 
{

    int16* Channel = (int16*)ioData->mBuffers[0].mData;

    uint32 Frequency = 256;
    uint32 Period = 48000/Frequency; 
    uint32 HalfPeriod = Period/2;

    local_persist uint32 RunningSampleIndex = 0;

    for (uint32 i = 0; i < inNumberFrames; i++) {
        if((RunningSampleIndex%Period) > HalfPeriod) {
            *Channel++ = 5000;
            *Channel++ = 5000; 
        } else {
            *Channel++ = -5000;
            *Channel++ = -5000; 
        }
 
        RunningSampleIndex++;
    }

    return noErr;
    
}

internal void
MacSetupAudio(AudioComponentInstance *AudioUnit)
{
    AudioComponentDescription Acd;
    Acd.componentType = kAudioUnitType_Output;
    Acd.componentSubType = kAudioUnitSubType_DefaultOutput;
    Acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    Acd.componentFlags = 0;
    Acd.componentFlagsMask = 0;

    AudioComponent OutputComponent = AudioComponentFindNext(NULL, &Acd);
    OSStatus Status = AudioComponentInstanceNew(OutputComponent, AudioUnit);

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error setting up sound");
        return;
    }

    AudioStreamBasicDescription AudioDescriptor;
    AudioDescriptor.mSampleRate = 48000;
    AudioDescriptor.mFormatID = kAudioFormatLinearPCM;
    AudioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                                   kAudioFormatFlagIsPacked; 
    int BytesPerFrame = sizeof(int16) * 2;
    AudioDescriptor.mFramesPerPacket = 1;
    AudioDescriptor.mChannelsPerFrame = 2; // Stereo sound
    AudioDescriptor.mBitsPerChannel = sizeof(int16) * 8;
    AudioDescriptor.mBytesPerFrame = BytesPerFrame;
    AudioDescriptor.mBytesPerPacket = BytesPerFrame; 

    Status = AudioUnitSetProperty(*AudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &AudioDescriptor,
                                  sizeof(AudioDescriptor));

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AURenderCallbackStruct RenderCallback;
    RenderCallback.inputProc = SquareWaveRenderCallback;

    Status = AudioUnitSetProperty(*AudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &RenderCallback,
                                  sizeof(RenderCallback));

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AudioUnitInitialize(*AudioUnit);
    AudioOutputUnitStart(*AudioUnit);
}

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *MainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

    real32 GlobalRenderWidth = 1024;
    real32 GlobalRenderHeight = 768;

    NSRect InitialFrame = NSMakeRect((ScreenRect.size.width - GlobalRenderWidth) * 0.5,
                                     (ScreenRect.size.height - GlobalRenderHeight) * 0.5,
                                     GlobalRenderWidth,
                                     GlobalRenderHeight);
    
    NSWindow *Window = [[KeyIgnoringWindow alloc] 
                         initWithContentRect: InitialFrame
                         styleMask: NSWindowStyleMaskTitled |
                                    NSWindowStyleMaskClosable |
                                    NSWindowStyleMaskMiniaturizable 
                         backing: NSBackingStoreBuffered
                         defer: NO];    

    [Window setBackgroundColor: NSColor.blackColor];
    [Window setTitle: @"Handmade Hero"];
    [Window makeKeyAndOrderFront: nil];
    [Window setDelegate: MainWindowDelegate];
    Window.contentView.wantsLayer = YES;
  
    mac_offscreen_buffer Buffer = {};
    Buffer.BytesPerPixel = 4;

    MacRefreshBuffer(&Buffer, Window);

    mac_game_controller PlaystationController = {};
    MacSetupGameController(&PlaystationController); 

    mac_game_controller KeyboardController = {};

    int OffsetX = 0;
    int OffsetY = 0;

    // NOTE: (ted)  This is where we decide what input to take.
    mac_game_controller *GameController = &KeyboardController; 

    AudioComponentInstance AudioUnit;
    MacSetupAudio(&AudioUnit);

    while(Running) {
   
        NSEvent* Event;
        
        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (Event != nil &&
                (Event.type == NSEventTypeKeyDown ||
                Event.type == NSEventTypeKeyUp)) 
            {
                MacHandleKeyboardEvent(&KeyboardController, Event);
            }

            switch ([Event type]) {
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);

        RenderWeirdGradient(&Buffer, OffsetX, OffsetY);
        MacRedrawBuffer(&Buffer, Window); 

        if (GameController->DPadX == 1)
        {
            OffsetX++;
        } else if (GameController->DPadX == -1)
        {
            OffsetX--;
        }

        if (GameController->LeftShoulderButtonState == true)
        {
            OffsetX--;
        }

        if (GameController->RightShoulderButtonState == true)
        {
            OffsetX++;
        }

        if (GameController->DPadY == 1)
        {
            OffsetY++;
        } else if (GameController->DPadY == -1)
        {
            OffsetY--;
        }

        if (GameController->XButtonState == true)
        {
            OffsetX++;
        }
    }
    
    printf("Handmade Finished Running");
}
