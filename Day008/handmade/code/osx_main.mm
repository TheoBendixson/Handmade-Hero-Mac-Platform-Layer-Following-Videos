// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>

// TODO: (ted) Move these to a separate file
#define internal static
#define local_persist static
#define global_variable static

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef int32_t bool32;

typedef float real32;
typedef double real64;

global_variable float GlobalRenderWidth = 1024;
global_variable float GlobalRenderHeight = 768;

global_variable bool Running = true;
global_variable uint8 *Buffer;
global_variable int BitmapWidth;
global_variable int BitmapHeight;
global_variable int BytesPerPixel = 4;
global_variable int Pitch;

const uint16 LeftArrowKeyCode = 0x7B;
const uint16 RightArrowKeyCode = 0x7C;
const uint16 DownArrowKeyCode = 0x7D;
const uint16 UpArrowKeyCode = 0x7E;
const uint16 AKeyCode = 0x00;
const uint16 SKeyCode = 0x01;
const uint16 DKeyCode = 0x02;
const uint16 FKeyCode = 0x03;
const uint16 QKeyCode = 0x0C;
const uint16 RKeyCode = 0x0F;
const uint16 LKeyCode = 0x25;


void MacRefreshBuffer(NSWindow *Window) {

    if (Buffer) {
        free(Buffer);
    }

    BitmapWidth = Window.contentView.bounds.size.width;
    BitmapHeight = Window.contentView.bounds.size.height;
    Pitch = BitmapWidth * BytesPerPixel;
    Buffer = (uint8 *)malloc(Pitch * BitmapHeight);
}

internal
void RenderWeirdGradient(int OffsetX, int OffsetY) 
{ 
    int Width = BitmapWidth;
    int Height = BitmapHeight;

    uint8 *Row = (uint8 *)Buffer;

    for (int Y = 0; Y < Height; ++Y) {

        uint8 *Pixel = (uint8 *)Row;

        for(int X = 0; X < Width; ++X) {
            
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

        Row += Pitch;
    }

}

void MacRedrawBuffer(NSWindow *Window) {
    @autoreleasepool {
        NSBitmapImageRep *Rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &Buffer 
                                  pixelsWide: BitmapWidth
                                  pixelsHigh: BitmapHeight
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bytesPerRow: Pitch
                                  bitsPerPixel: BytesPerPixel * 8] autorelease];

        NSSize ImageSize = NSMakeSize(BitmapWidth, BitmapHeight);
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

struct mac_game_controller
{
    uint32 SquareButtonUsageID;
    uint32 TriangleButtonUsageID;
    uint32 XButtonUsageID;
    uint32 CircleButtonUsageID;
    uint32 LeftShoulderButtonUsageID;
    uint32 RightShoulderButtonUsageID;

    uint32 LeftThumbXUsageID;
    uint32 LeftThumbYUsageID;

    bool32 SquareButtonState;
    bool32 TriangleButtonState;
    bool32 XButtonState;
    bool32 CircleButtonState;
    bool32 LeftShoulderButtonState;
    bool32 RightShoulderButtonState;

    real32 LeftThumbstickX;
    real32 LeftThumbstickY;

    int32 DPadX;
    int32 DPadY;

};

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

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *MainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

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
   
    MacRefreshBuffer(Window);

    // TODO: (ted)  Setup Playstation Controller USB Handling
    mac_game_controller PlaystationController = {};
    MacSetupGameController(&PlaystationController); 

    mac_game_controller KeyboardController = {};

    int OffsetX = 0;
    int OffsetY = 0;

    // NOTE: (ted)  This is where we decide what input to take.
    mac_game_controller *GameController = &KeyboardController; 

    while(Running) {
   
        NSEvent* Event;
        
        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            switch ([Event type]) {
                case NSEventTypeKeyDown:
                    if (Event.keyCode == UpArrowKeyCode)
                    {

                    }

                    if (Event.keyCode == AKeyCode)
                    {
                        KeyboardController.XButtonState = true;
                    }
                    [NSApp sendEvent: Event];
                    break;
                case NSEventTypeKeyUp:
                    if (Event.keyCode == AKeyCode)
                    {
                        KeyboardController.XButtonState = false;
                    }
                    [NSApp sendEvent: Event];
                    break;
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);

        RenderWeirdGradient(OffsetX, OffsetY);
        MacRedrawBuffer(Window); 

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
