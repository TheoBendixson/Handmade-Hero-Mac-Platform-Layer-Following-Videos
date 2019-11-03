// Handmade Hero Mac OS Platform Layer
// By Theodore William Bendixson 
#import <AudioToolbox/AudioToolbox.h>
#include "handmade_types.h"

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

struct mac_offscreen_buffer
{
    uint8 *Memory;
    uint32 Width;
    uint32 Height;
    uint32 BytesPerPixel;
    uint32 Pitch;
};

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

struct mac_sound_output
{
    int32 SamplesPerSecond;
    int32 BytesPerSample;
    uint32 BufferSize;
    //
    // NOTE: (ted)  This isn't the real sound card play cursor.
    //              it's just the last time Core Audio / Apple called us.
    uint32 PlayCursor;
    void *Data;

    AudioComponentInstance *AudioUnit;
};
