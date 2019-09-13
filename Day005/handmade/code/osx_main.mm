// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>

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

global_variable float GlobalRenderWidth = 1024;
global_variable float GlobalRenderHeight = 768;

global_variable bool Running = true;
global_variable uint8 *Buffer;
global_variable int BitmapWidth;
global_variable int BitmapHeight;
global_variable int BytesPerPixel = 4;
global_variable int Pitch;

global_variable int OffsetX = 0;

void MacRefreshBuffer(NSWindow *Window) {

    if (Buffer) {
        free(Buffer);
    }

    BitmapWidth = Window.contentView.bounds.size.width;
    BitmapHeight = Window.contentView.bounds.size.height;
    Pitch = BitmapWidth * BytesPerPixel;
    Buffer = (uint8 *)malloc(Pitch * BitmapHeight);
}

void RenderWeirdGradient() {

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
            *Pixel = (uint8)Y;
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

- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *Window = (NSWindow*)notification.object;
    MacRefreshBuffer(Window);
    RenderWeirdGradient();
    MacRedrawBuffer(Window);
}

@end

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *MainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

    NSRect InitialFrame = NSMakeRect((ScreenRect.size.width - GlobalRenderWidth) * 0.5,
                                     (ScreenRect.size.height - GlobalRenderHeight) * 0.5,
                                     GlobalRenderWidth,
                                     GlobalRenderHeight);
    
    NSWindow *Window = [[NSWindow alloc] 
                         initWithContentRect: InitialFrame
                         styleMask: NSWindowStyleMaskTitled |
                                    NSWindowStyleMaskClosable |
                                    NSWindowStyleMaskMiniaturizable |
                                    NSWindowStyleMaskResizable 
                         backing: NSBackingStoreBuffered
                         defer: NO];    

    [Window setBackgroundColor: NSColor.blackColor];
    [Window setTitle: @"Handmade Hero"];
    [Window makeKeyAndOrderFront: nil];
    [Window setDelegate: MainWindowDelegate];
    Window.contentView.wantsLayer = YES;
   
    MacRefreshBuffer(Window);
 
    while(Running) {
   
        RenderWeirdGradient();
        MacRedrawBuffer(Window); 

        OffsetX++;
        
        NSEvent* Event;
        
        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
            
            switch ([Event type]) {
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);
    }
    
    printf("Handmade Finished Running");
}
