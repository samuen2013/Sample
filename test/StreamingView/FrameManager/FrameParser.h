#pragma once

#import "EAGLView.h"

class FrameParser
{
public:
    static TRenderInfo parseRenderInfo(BYTE **ppbyData, DWORD dwOffset);

private:
    static void parseOldMotionWindow(BYTE **ppbyData, DWORD *pdwDataSize);
    static void passReservedBitField(BYTE **ppbyData, DWORD *pdwDataSize);
};
