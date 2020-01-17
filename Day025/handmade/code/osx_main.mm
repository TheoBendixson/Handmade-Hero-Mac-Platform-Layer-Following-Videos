// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <math.h>
#include "osx_main.h"
#include <sys/stat.h>

global_variable bool Running = true;

// NOTE: (Ted)  Not sure how this performs when the app directory is a symbolic link
internal void
MacBuildAppFilePath(mac_app_path *Path)
{
    uint32 BufferSize = sizeof(Path->Filename);
    if (_NSGetExecutablePath(Path->Filename, &BufferSize) == 0)
    {
        for (char *Scan = Path->Filename;
             *Scan; Scan++)
        {
            if (*Scan == '/')
            {
                Path->OnePastLastAppFileNameSlash = Scan + 1;
            }
        }
    }
}

// TODO: Destination bounds checking
internal void
CatStrings(size_t SourceACount, char *SourceA,
           size_t SourceBCount, char *SourceB,
           size_t DestCount, char *Dest)
{
    
    for(uint32 Index = 0;
        Index < SourceACount;
        ++Index)
    {
        *Dest++ = *SourceA++;
    }

    for(uint32 Index = 0;
        Index < SourceBCount;
        ++Index)
    {
        *Dest++ = *SourceB++;
    }

    *Dest++ = 0;
}

internal uint32
StringLength(char *String)
{
    uint32 Count = 0;
    while(*String++)
    {
        ++Count;
    }
    return(Count);
}

internal void
MacBuildAppPathFilename(mac_app_path *Path, char *Filename, uint32 DestCount, char *Dest)
{
    size_t PathFileNameSize = (size_t)(Path->OnePastLastAppFileNameSlash - Path->Filename);
    CatStrings(PathFileNameSize, Path->Filename,
               StringLength(Filename), Filename,
               DestCount, Dest);
}

#if HANDMADE_INTERNAL
DEBUG_PLATFORM_FREE_FILE_MEMORY(DEBUGPlatformFreeFileMemory)
{
    if (Memory)
    {
        free(Memory);
    }
}

DEBUG_PLATFORM_READ_ENTIRE_FILE(DEBUGPlatformReadEntireFile)
{
    debug_read_file_result Result = {};

    mac_app_path Path = {};
    MacBuildAppFilePath(&Path);

    // NOTE: (Ted)  This is the file location in the bundle.
    char BundleFilename[MAC_MAX_FILENAME_SIZE];
    char LocalFilename[MAC_MAX_FILENAME_SIZE];

    // TODO: (Ted)  Put all of this into our own string functions.
    sprintf(LocalFilename, "Contents/Resources/%s", Filename);

    // Contents/Resources/test_background.bmp
    MacBuildAppPathFilename(&Path, LocalFilename,
                            sizeof(BundleFilename), BundleFilename);

    // TODO: (Ted)  Actually load the bitmap!!!
    FILE *FileHandle = fopen(BundleFilename, "r+");

    if (FileHandle != NULL)
    {
        fseek(FileHandle, 0, SEEK_END);
        uint64 FileSize = (uint64)ftell(FileHandle);

        if (FileSize)
        {
        	rewind(FileHandle);
            Result.Contents = malloc(FileSize);

            if (Result.Contents)
            {
                uint64 BytesRead = fread(Result.Contents, 1, FileSize, FileHandle);
                if (BytesRead == FileSize)
                {
                    // Successfully read the file.
                    Result.ContentsSize = (uint32)FileSize;

                } else
                {
                    // TODO: Clean this up. 
                    DEBUGPlatformFreeFileMemory(Result.Contents);
                    Result.ContentsSize = 0;
                }
            } else
            {
                // TODO: Log this.
            }
        } else
        {
            // TODO: Log this.
        }
    } else 
    {
        // TODO: Log this.
    }

    return (Result);
}

DEBUG_PLATFORM_WRITE_ENTIRE_FILE(DEBUGPlatformWriteEntireFile)
{
    bool32 Result = false;

    // TODO: Ted    Consider cleaning this up / compressing it?
    mac_app_path Path = {};
    MacBuildAppFilePath(&Path);

    char BundleFilename[MAC_MAX_FILENAME_SIZE];
    char LocalFilename[MAC_MAX_FILENAME_SIZE];

    sprintf(LocalFilename, "Contents/%s", Filename);

    MacBuildAppPathFilename(&Path, LocalFilename,
                            sizeof(BundleFilename), BundleFilename);

    FILE *FileHandle = fopen(BundleFilename, "w");

    if (FileHandle)
    {
        uint64 BytesWritten = fwrite(Memory, 1, FileSize, FileHandle);
        if (BytesWritten == FileSize)
        {
            Result = true;
        } else
        {
            // TODO: Log this.
        }
    } else
    {
        // TODO: Log this
    }

    return Result;
}
#endif

// TODO: (Ted)
// 1. Free file memory
// 2. Debug write file

void MacRefreshBuffer(game_offscreen_buffer *Buffer, NSWindow *Window) {

    if (Buffer->Memory) {
        free(Buffer->Memory);
    }

    Buffer->Width = (uint32)Window.contentView.bounds.size.width;
    Buffer->Height = (uint32)Window.contentView.bounds.size.height;
    Buffer->Pitch = Buffer->Width * Buffer->BytesPerPixel;
    Buffer->Memory = (uint8 *)malloc(Buffer->Pitch * Buffer->Height);
}


// TODO: (Ted)  Replace this with hardware rendering.
void MacRedrawBuffer(game_offscreen_buffer *Buffer, NSWindow *Window) {
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
MacBeginRecordingInput(mac_state *MacState)
{
    if (MacState->ReplayMemoryBlock)
    {
        MacState->RecordingHandle = MacState->ReplayFileHandle;
        fseek(MacState->RecordingHandle, (int64)MacState->PermanentStorageSize, SEEK_SET);
        memcpy(MacState->ReplayMemoryBlock, MacState->GameMemoryBlock, MacState->PermanentStorageSize);
        MacState->IsRecording = true;
    }
}

internal void
MacEndRecordingInput(mac_state *MacState)
{
    MacState->IsRecording = false;
}

internal void
MacBeginInputPlayback(mac_state *MacState)
{
    if (MacState->ReplayMemoryBlock)
    {
        MacState->PlaybackHandle = MacState->ReplayFileHandle;
        fseek(MacState->PlaybackHandle, (int64)MacState->PermanentStorageSize, SEEK_SET);
        memcpy(MacState->GameMemoryBlock, MacState->ReplayMemoryBlock, MacState->PermanentStorageSize);
        MacState->IsPlayingBack = true;
    }
}

internal void
MacEndInputPlayback(mac_state *MacState)
{
    MacState->IsPlayingBack = false;
}

internal void
MacRecordInput(mac_state *MacState, game_input *NewInput)
{
    size_t BytesWritten = fwrite(NewInput, sizeof(char), sizeof(*NewInput), MacState->RecordingHandle);
    if (BytesWritten <= 0)
    {
        // TODO: (ted) Log Record Input Failure
    }
}

internal void
MacPlaybackInput(mac_state *MacState, game_input *NewInput)
{
    uint64 BytesRead = fread(NewInput, sizeof(char), sizeof(*NewInput), MacState->PlaybackHandle);
    if (BytesRead <= 0) 
    {
        MacEndInputPlayback(MacState); 
        MacBeginInputPlayback(MacState);
    }
}

// TODO: (Ted)  Test this again.
internal void
MacHandleKeyboardEvent(mac_game_controller *GameController, NSEvent *Event, mac_state *MacState)
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
        else if (Event.keyCode == LKeyCode)
        {
            if (MacState->IsPlayingBack)
            {
                MacEndInputPlayback(MacState);
                break;
            }

            if (!MacState->IsRecording)
            {
                MacBeginRecordingInput(MacState);
            } else 
            {
                MacEndRecordingInput(MacState);
                MacBeginInputPlayback(MacState);
                break;
            }
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
CoreAudioRenderCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        uint32 inBusNumber,
                        uint32 inNumberFrames,
                        AudioBufferList *ioData) 
{
    mac_sound_output *SoundOutput = (mac_sound_output *)inRefCon;

    uint32 BytesToOutput = inNumberFrames * SoundOutput->BytesPerSample; 

    // NOTE: (ted)  Region 1 is the number of bytes up to the end of the sound buffer
    //              If the frames to be rendered causes us to wrap, the remainder goes
    //              into Region 2.
    uint32 Region1Size = BytesToOutput;
    uint32 Region2Size = 0;

    // NOTE: (ted)  This handles the case where we wrap.
    if (SoundOutput->PlayCursor + BytesToOutput > SoundOutput->BufferSize) 
    {
        // NOTE: (ted)  Region 1 is the distance from the Play Cursor
        //              to the end of the sound buffer, a.k.a. BufferSize
        Region1Size = SoundOutput->BufferSize - SoundOutput->PlayCursor;

        // NOTE: (ted)  Region 2 is whatever is left over.
        Region2Size = BytesToOutput - Region1Size;
    } 

    uint8* Channel = (uint8*)ioData->mBuffers[0].mData;

    memcpy(Channel, 
           (uint8*)SoundOutput->Data + SoundOutput->PlayCursor, 
           Region1Size);

    memcpy(&Channel[Region1Size],
           SoundOutput->Data,
           Region2Size);

    // Finally, move the play cursor
    SoundOutput->PlayCursor = (SoundOutput->PlayCursor + BytesToOutput) % SoundOutput->BufferSize;

    return noErr;
}

internal void
MacSetupAudio(mac_sound_output *SoundOutput)
{
    SoundOutput->SamplesPerSecond = 48000; 
    uint32 AudioFrameSize = sizeof(int16) * 2;
    uint32 NumberOfSeconds = 2; 
    SoundOutput->BytesPerSample = AudioFrameSize; 

    // NOTE: (ted)  Allocate a two second sound buffer
    SoundOutput->BufferSize = SoundOutput->SamplesPerSecond * AudioFrameSize * NumberOfSeconds;
    SoundOutput->Data = malloc(SoundOutput->BufferSize);
    SoundOutput->PlayCursor = 0;

    AudioComponentInstance AudioUnit;
    SoundOutput->AudioUnit = &AudioUnit;

    AudioComponentDescription Acd;
    Acd.componentType = kAudioUnitType_Output;
    Acd.componentSubType = kAudioUnitSubType_DefaultOutput;
    Acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    Acd.componentFlags = 0;
    Acd.componentFlagsMask = 0;

    AudioComponent OutputComponent = AudioComponentFindNext(NULL, &Acd);
    OSStatus Status = AudioComponentInstanceNew(OutputComponent, SoundOutput->AudioUnit);

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error setting up sound");
        return;
    }

    // TODO: (Ted) Make this dependent of the frame rate. 
    uint32 TargetSoundFrameSize = 1024;

    Status = AudioUnitSetProperty(*SoundOutput->AudioUnit,
                                  kAudioDevicePropertyBufferFrameSize,
                                  kAudioUnitScope_Global,
                                  0,
                                  &TargetSoundFrameSize, sizeof(uint32));  

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error setting the sound frame size");
        return;
    }

    uint32 DataSize = sizeof(uint32);
    uint32 CurrentBufferFrameSize = 0;

    Status = AudioUnitGetProperty(*SoundOutput->AudioUnit,
                                  kAudioDevicePropertyBufferFrameSize,
                                  kAudioUnitScope_Global,
                                  0,
                                  &CurrentBufferFrameSize, &DataSize);  

    //todo: (ted) - Better error handling 
    if (Status != noErr) {
        NSLog(@"There was an error getting the current buffer frame size");
        return;
    }

    NSLog(@"Current Sound Buffer Frame Size: %u", CurrentBufferFrameSize);

    AudioStreamBasicDescription AudioDescriptor;
    AudioDescriptor.mSampleRate = SoundOutput->SamplesPerSecond;
    AudioDescriptor.mFormatID = kAudioFormatLinearPCM;
    AudioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                                   kAudioFormatFlagIsPacked; 
    AudioDescriptor.mFramesPerPacket = 1;
    AudioDescriptor.mChannelsPerFrame = 2; // Stereo sound
    AudioDescriptor.mBitsPerChannel = sizeof(int16) * 8;
    AudioDescriptor.mBytesPerFrame = SoundOutput->BytesPerSample;
    AudioDescriptor.mBytesPerPacket = SoundOutput->BytesPerSample; 

    Status = AudioUnitSetProperty(*SoundOutput->AudioUnit,
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
    RenderCallback.inputProcRefCon = (void *)SoundOutput;
    RenderCallback.inputProc = CoreAudioRenderCallback;

    Status = AudioUnitSetProperty(*SoundOutput->AudioUnit,
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

    AudioUnitInitialize(*SoundOutput->AudioUnit);
    AudioOutputUnitStart(*SoundOutput->AudioUnit);
}

internal
void MacProcessGameControllerButton(game_button_state *OldState,
                                    game_button_state *NewState,
                                    bool32 NewIsDown)
{
    NewState->EndedDown = NewIsDown;
    NewState->HalfTransitionCount += ((NewState->EndedDown == OldState->EndedDown) ? 0:1);
}

internal real32
MacGetSecondsElapsed(mach_timebase_info_data_t *TimeBase,
                     uint64 Start, uint64 End)
{
    uint64 Elapsed = End - Start;
    real32 Result = (real32)(Elapsed * (TimeBase->numer / TimeBase->denom)) / 1000.0f / 1000.0f / 1000.0f;
    return (Result);
}

inline time_t
MacGetLastWriteTime(char *Filename)
{
    time_t Result = 0;

    struct stat StatData = {};

    if (stat(Filename, &StatData) == 0)
    {
        Result = StatData.st_mtime;
    }

    return (Result);
}

internal
void MacLoadGameCode(mac_game_code *Game, char *GameLibraryFullPath)
{
    Game->DLLLastWriteTime = MacGetLastWriteTime(GameLibraryFullPath);
    Game->GameCodeDLL = dlopen(GameLibraryFullPath, RTLD_NOW);
    if (Game->GameCodeDLL)
    {
        Game->UpdateAndRender = (game_update_and_render *)
                                dlsym(Game->GameCodeDLL, "GameUpdateAndRender");

        Game->GetSoundSamples = (game_get_sound_samples *)
                                dlsym(Game->GameCodeDLL, "GameGetSoundSamples");

        Game->IsValid = (Game->UpdateAndRender &&
                         Game->GetSoundSamples);
    }

    if (!Game->IsValid)
    {
        printf("Dynamic Library Load Error: %s", dlerror());
        Game->UpdateAndRender = 0;
        Game->GetSoundSamples = 0;
    }
}

internal
void MacUnloadGameCode(mac_game_code *Game)
{
    if(Game->GameCodeDLL)
    {
        dlclose(Game->GameCodeDLL);
        Game->GameCodeDLL = 0;
    }

    Game->IsValid = false;
    Game->UpdateAndRender = 0;
    Game->GetSoundSamples = 0;
}

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *MainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

    real32 GlobalRenderWidth = 1024;
    real32 GlobalRenderHeight = 768;

    NSRect InitialFrame = NSMakeRect((ScreenRect.size.width - (real64)GlobalRenderWidth) * 0.5,
                                     (ScreenRect.size.height - (real64)GlobalRenderHeight) * 0.5,
                                     (real64)GlobalRenderWidth, (real64)GlobalRenderHeight);
    
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
 
    mac_state MacState = {};
    MacState.IsRecording = false;
    MacState.IsPlayingBack = false;

    mac_app_path Path = {};
    MacState.Path = Path; 
    MacBuildAppFilePath(&MacState.Path);

    game_offscreen_buffer Buffer = {};
    Buffer.BytesPerPixel = 4;

    MacRefreshBuffer(&Buffer, Window);

    game_memory GameMemory = {}; 
    GameMemory.DEBUGPlatformReadEntireFile = DEBUGPlatformReadEntireFile;
    GameMemory.DEBUGPlatformFreeFileMemory = DEBUGPlatformFreeFileMemory;
    GameMemory.DEBUGPlatformWriteEntireFile = DEBUGPlatformWriteEntireFile;
   
    GameMemory.PermanentStorageSize = Megabytes(64);
    GameMemory.TransientStorageSize = Gigabytes(4);

#if HANDMADE_INTERNAL
    char *BaseAddress = (char *)Gigabytes(8);
    int32 AllocationFlags = MAP_PRIVATE | MAP_ANON | MAP_FIXED;
#else
    void *BaseAddress = 0;
    int32 AllocationFlags = MAP_PRIVATE | MAP_ANON;
#endif 
    
    int32 AccessFlags = PROT_READ | PROT_WRITE;

    uint64 TotalSize = GameMemory.PermanentStorageSize + GameMemory.TransientStorageSize;

    GameMemory.PermanentStorage = mmap(BaseAddress, GameMemory.PermanentStorageSize, AccessFlags, 
                                       AllocationFlags, -1, 0);
    
    if (GameMemory.PermanentStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Permanent Storage Not Allocated"
                     format: @"Failed to allocate permanent storage"];
    }
    
    uint8 *TransientStorageAddress = ((uint8*)GameMemory.PermanentStorage + GameMemory.PermanentStorageSize);
    GameMemory.TransientStorage = mmap(TransientStorageAddress, GameMemory.TransientStorageSize,
                                       AccessFlags, AllocationFlags, -1, 0);

    if (GameMemory.TransientStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Transient Storage Not Allocated"
                     format: @"Failed to allocate transient storage"];
    }

    MacState.GameMemoryBlock = GameMemory.PermanentStorage;
    MacState.PermanentStorageSize = GameMemory.PermanentStorageSize;

    int FileDescriptor;
    mode_t Mode = S_IRUSR | S_IWUSR;
    char Filename[MAC_MAX_FILENAME_SIZE];
    char LocalFilename[MAC_MAX_FILENAME_SIZE];
    sprintf(LocalFilename, "Contents/Resources/ReplayBuffer");
    MacBuildAppPathFilename(&MacState.Path, LocalFilename,
                            sizeof(Filename), Filename);
    FileDescriptor = open(Filename, O_CREAT | O_RDWR, Mode);
    int Result = truncate(Filename, (int64)GameMemory.PermanentStorageSize);

    if (Result < 0)
    {
        // TODO: (ted)  Log This
    }

    MacState.ReplayMemoryBlock = mmap(0, GameMemory.PermanentStorageSize,
                                      PROT_READ | PROT_WRITE,
                                      MAP_PRIVATE, FileDescriptor, 0);
    MacState.ReplayFileHandle = fopen(Filename, "r+");

    fseek(MacState.ReplayFileHandle, (int)MacState.PermanentStorageSize, SEEK_SET);
    if (MacState.ReplayMemoryBlock)
    {
    } else {
        // TODO: (casey)    Diagnostic
    }

    mac_game_controller PlaystationController = {};
    MacSetupGameController(&PlaystationController); 

    mac_game_controller KeyboardController = {};

    mac_game_controller *MacControllers[2] = { &KeyboardController, &PlaystationController };

    game_input Input[2] = {};
    game_input *NewInput = &Input[0];
    game_input *OldInput = &Input[1];

    mac_sound_output SoundOutput = {};
    MacSetupAudio(&SoundOutput);

    game_sound_output_buffer SoundBuffer = {};
    int16 *Samples = (int16*)calloc(SoundOutput.SamplesPerSecond,
                                    SoundOutput.BytesPerSample);

    SoundBuffer.SamplesPerSecond = SoundOutput.SamplesPerSecond;
    uint32 LatencySampleCount = SoundOutput.SamplesPerSecond / 15;
    uint32 TargetQueueBytes = LatencySampleCount * SoundOutput.BytesPerSample;

    local_persist uint32 RunningSampleIndex = 0;

    // TODO: Determine this programmatically.
    int32 MonitorRefreshHz = 60;
    real32 TargetFramesPerSecond = MonitorRefreshHz / 2.0f;
    real32 TargetSecondsPerFrame = 1.0f / TargetFramesPerSecond; 

    char *GameLibraryInBundlePath = (char *)"Contents/Resources/GameCode.dylib";
    char GameLibraryFullPath[MAC_MAX_FILENAME_SIZE];

    MacBuildAppPathFilename(&MacState.Path, GameLibraryInBundlePath,
                            sizeof(GameLibraryFullPath), GameLibraryFullPath);

    mac_game_code Game = {};
    MacLoadGameCode(&Game, GameLibraryFullPath); 

    mach_timebase_info_data_t TimeBase;
    mach_timebase_info(&TimeBase);

    uint64 LastCounter = mach_absolute_time();     

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
                MacHandleKeyboardEvent(&KeyboardController, Event, &MacState);
            }

            switch ([Event type]) {
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);

        game_input *Temp = NewInput;
        NewInput = OldInput;
        OldInput = Temp;

        for (int MacControllerIndex = 0;
             MacControllerIndex < 2;
             MacControllerIndex++)
        {
            mac_game_controller *MacController = MacControllers[MacControllerIndex]; 

            game_controller_input *OldController = &OldInput->Controllers[MacControllerIndex];
            game_controller_input *NewController = &NewInput->Controllers[MacControllerIndex];

            // NOTE: (Ted)   Update Game Controler Inputs
            MacProcessGameControllerButton(&(OldController->A),
                                           &(NewController->A),
                                           MacController->CircleButtonState);

            MacProcessGameControllerButton(&(OldController->B),
                                           &(NewController->B),
                                           MacController->XButtonState);

            MacProcessGameControllerButton(&(OldController->X),
                                           &(NewController->X),
                                           MacController->TriangleButtonState);

            MacProcessGameControllerButton(&(OldController->Y),
                                           &(NewController->Y),
                                           MacController->SquareButtonState);

            MacProcessGameControllerButton(&(OldController->LeftShoulder),
                                           &(NewController->LeftShoulder),
                                           MacController->LeftShoulderButtonState);

            MacProcessGameControllerButton(&(OldController->RightShoulder),
                                           &(NewController->RightShoulder),
                                           MacController->RightShoulderButtonState);

            bool32 Right = MacController->DPadX > 0 ? true:false;
            bool32 Left = MacController->DPadX < 0 ? true:false;
            bool32 Up = MacController->DPadY > 0 ? true:false;
            bool32 Down = MacController->DPadY < 0 ? true:false;

            MacProcessGameControllerButton(&(OldController->Right),
                                           &(NewController->Right),
                                           Right);
            MacProcessGameControllerButton(&(OldController->Left),
                                           &(NewController->Left),
                                           Left);
            MacProcessGameControllerButton(&(OldController->Up),
                                           &(NewController->Up),
                                           Up);
            MacProcessGameControllerButton(&(OldController->Down),
                                           &(NewController->Down),
                                           Down);

            // TODO: (Ted)  Figure out if controller really is analog.
            NewController->IsAnalog = true; 

            NewController->StartX = OldController->EndX;
            NewController->StartY = OldController->EndY;

            NewController->EndX = (real32)(MacController->LeftThumbstickX - 127.5f)/127.5f;
            NewController->EndY = (real32)(MacController->LeftThumbstickY - 127.5f)/127.5f;

            NewController->MinX = NewController->MaxX = NewController->EndX;
            NewController->MinY = NewController->MaxY = NewController->EndY;
        }

        uint32 TargetCursor = ((SoundOutput.PlayCursor + TargetQueueBytes) % SoundOutput.BufferSize);

        uint32 ByteToLock = (RunningSampleIndex*SoundOutput.BytesPerSample) % SoundOutput.BufferSize; 
        uint32 BytesToWrite;

         if (ByteToLock > TargetCursor) {
            // NOTE: (ted)  Play Cursor wrapped.

            // Bytes to the end of the circular buffer.
            BytesToWrite = (SoundOutput.BufferSize - ByteToLock);

            // Bytes up to the target cursor.
            BytesToWrite += TargetCursor;
        } else {
            BytesToWrite = TargetCursor - ByteToLock;
        }

        // NOTE: (Ted)  This is where we can calculate the number of sound samples to write
        //              to the game_sound_output_buffer
        SoundBuffer.Samples = Samples;
        SoundBuffer.SampleCount = (BytesToWrite/SoundOutput.BytesPerSample);

        time_t NewGameLibraryWriteTime = MacGetLastWriteTime(GameLibraryFullPath);

        if (Game.DLLLastWriteTime < NewGameLibraryWriteTime)
        {
            MacUnloadGameCode(&Game); 
            MacLoadGameCode(&Game, GameLibraryFullPath); 
        }

        if (MacState.IsRecording)
        {
            MacRecordInput(&MacState, NewInput);
        } else if (MacState.IsPlayingBack)
        {
            MacPlaybackInput(&MacState, NewInput);
        }

        Game.UpdateAndRender(&GameMemory, NewInput, &Buffer);
        Game.GetSoundSamples(&GameMemory, &SoundBuffer);

        void *Region1 = (uint8*)SoundOutput.Data + ByteToLock;
        uint32 Region1Size = BytesToWrite;
        
        if (Region1Size + ByteToLock > SoundOutput.BufferSize) {
            Region1Size = SoundOutput.BufferSize - ByteToLock;
        }

        void *Region2 = SoundOutput.Data;
        uint32 Region2Size = BytesToWrite - Region1Size;

        uint32 Region1SampleCount = Region1Size/SoundOutput.BytesPerSample;
        int16* SampleOut = (int16*)Region1;

        for (uint32 SampleIndex = 0;
             SampleIndex < Region1SampleCount;
             ++SampleIndex) {
            *SampleOut++ = *SoundBuffer.Samples++;
            *SampleOut++ = *SoundBuffer.Samples++;
            RunningSampleIndex++;
        }

        uint32 Region2SampleCount = Region2Size/SoundOutput.BytesPerSample;
        SampleOut = (int16*)Region2;
       
        for (uint32 SampleIndex = 0;
             SampleIndex < Region2SampleCount;
             ++SampleIndex) {
            *SampleOut++ = *SoundBuffer.Samples++;
            *SampleOut++ = *SoundBuffer.Samples++;
            RunningSampleIndex++;
        }

        uint64 WorkCounter = mach_absolute_time();

        real32 WorkSeconds = MacGetSecondsElapsed(&TimeBase, LastCounter,
                                                  WorkCounter);

        real32 SecondsElapsedForFrame = WorkSeconds;

        if (SecondsElapsedForFrame < TargetSecondsPerFrame)
        {
            // NOTE: We need to sleep up to the target framerate 

            real32 UnderOffset = 3.0f / 1000.0f;
            real32 SleepTime = TargetSecondsPerFrame - SecondsElapsedForFrame - UnderOffset;
            useconds_t SleepMS = (useconds_t)(1000.0f * 1000.0f * SleepTime);
            
            if (SleepMS > 0)
            {
                usleep(SleepMS);
            }

            while (SecondsElapsedForFrame < TargetSecondsPerFrame)
            {
                SecondsElapsedForFrame = MacGetSecondsElapsed(&TimeBase, LastCounter,
                                                              mach_absolute_time());
            }

        } else
        {
            // TODO: Log MISSED FRAME RATE!!!
        }
    
        // NOTE: End of Updates
        uint64 EndOfFrameTime = mach_absolute_time();

        uint64 TimeUnitsPerFrame = EndOfFrameTime - LastCounter;

        // Here is where you print stuff..
        uint64 NanosecondsPerFrame = TimeUnitsPerFrame * (TimeBase.numer / TimeBase.denom);
        real32 SecondsPerFrame = (real32)NanosecondsPerFrame * (real32)1.0E-9;
        real32 MillesSecondsPerFrame = (real32)NanosecondsPerFrame * (real32)1.0E-6;
        real32 FramesPerSecond = 1 / SecondsPerFrame;

        NSLog(@"Frames Per Second: %f", (real64)FramesPerSecond); 
        NSLog(@"MillesSecondsPerFrame: %f", (real64)MillesSecondsPerFrame); 

        LastCounter = mach_absolute_time();

        MacRedrawBuffer(&Buffer, Window); 
    }
    
    printf("Handmade Finished Running");
}
