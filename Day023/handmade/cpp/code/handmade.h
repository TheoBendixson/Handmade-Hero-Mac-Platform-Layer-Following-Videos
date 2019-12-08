// Cross Platform Game Library

#define Kilobytes(Value) ((Value)*1024LL)
#define Megabytes(Value) (Kilobytes(Value)*1024LL)
#define Gigabytes(Value) (Megabytes(Value)*1024LL)

#if HANDMADE_INTERNAL
struct debug_read_file_result
{
    void *Contents;
    uint32 ContentsSize; 
};

extern "C" {
#define DEBUG_PLATFORM_READ_ENTIRE_FILE(name) debug_read_file_result name(char *Filename)
typedef DEBUG_PLATFORM_READ_ENTIRE_FILE(debug_platform_read_entire_file);

#define DEBUG_PLATFORM_FREE_FILE_MEMORY(name) void name(void *Memory)
typedef DEBUG_PLATFORM_FREE_FILE_MEMORY(debug_platform_free_file_memory);

#define DEBUG_PLATFORM_WRITE_ENTIRE_FILE(name) bool32 name(char *Filename, uint64 FileSize, void *Memory)
typedef DEBUG_PLATFORM_WRITE_ENTIRE_FILE(debug_platform_write_entire_file);

#endif

struct game_offscreen_buffer
{
    uint8 *Memory;
    uint32 Width;
    uint32 Height;
    uint32 BytesPerPixel;
    uint32 Pitch;
};

struct game_sound_output_buffer
{
    int16 *Samples;
    uint32 SampleCount;
    uint32 SamplesPerSecond;
};

struct game_button_state {
    int HalfTransitionCount;
    bool32 EndedDown;
};

struct game_controller_input
{
    bool32 IsAnalog;

    real32 StartX;
    real32 StartY;

    real32 MinX;
    real32 MinY;

    real32 MaxX;
    real32 MaxY;

    real32 EndX;
    real32 EndY;

    union {
        game_button_state Buttons[10];
        struct {
            game_button_state Up;
            game_button_state Down;
            game_button_state Left;
            game_button_state Right;
            game_button_state A;
            game_button_state B;
            game_button_state X;
            game_button_state Y;
            game_button_state LeftShoulder;
            game_button_state RightShoulder;
        };
    };
};

struct game_input 
{
    game_controller_input Controllers[2];
};

struct game_memory
{
    uint64 PermanentStorageSize;
    void *PermanentStorage;

    uint64 TransientStorageSize;
    void *TransientStorage;

    bool32 IsInitialized;

    debug_platform_read_entire_file *DEBUGPlatformReadEntireFile;
    debug_platform_free_file_memory *DEBUGPlatformFreeFileMemory;
    debug_platform_write_entire_file *DEBUGPlatformWriteEntireFile;
};

struct game_state
{
    int OffsetX;
    int OffsetY;
    uint32 ToneHz;
};

#define GAME_GET_SOUND_SAMPLES(name) void name(game_memory *Memory, game_sound_output_buffer *SoundBuffer)
typedef GAME_GET_SOUND_SAMPLES(game_get_sound_samples);

#define GAME_UPDATE_AND_RENDER(name) void name(game_memory *Memory, game_input *Input, game_offscreen_buffer *Buffer) 
typedef GAME_UPDATE_AND_RENDER(game_update_and_render);
}
