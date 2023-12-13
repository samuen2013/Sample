//
//  StreamingStatus.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/11/30.
//

#pragma once

typedef NS_ENUM(NSInteger, StreamingStatus)
{
    StreamingStatusInitial = -1,
    StreamingStatusConnecting = 0,
    StreamingStatusConnected = 1,
    StreamingStatusDisconnected = 2,
    StreamingStatusReceiveConnectionInfo = 3,
    StreamingStatusUnsupportedCodec = 4,
    StreamingStatusTooManyConnections = 429
};

typedef NS_ENUM(NSInteger, StreamingVideoCodec)
{
    StreamingVideoCodecH264,
    StreamingVideoCodecH265,
    StreamingVideoCodecMPEG4,
    StreamingVideoCodecJPEG,
    StreamingVideoCodecUnknown
};

typedef NS_ENUM(NSInteger, FisheyeDewarpType)
{
    FisheyeDewarpOriginal = 0,   // No dewarp
    FisheyeDewarpPanoramic = 1,  // panorama projection
    FisheyeDewarpRegional = 2,   // rectilinear projection
    FisheyeDewarpFullHD = 3      // FullHD
};

typedef NS_ENUM(NSInteger, FisheyeMountType)
{
    FisheyeMountTypeUnknown = -1,
    FisheyeMountTypeWall = 0,
    FisheyeMountTypeCeiling = 1,
    FisheyeMountTypeFloor = 2,
    FisheyeMountTypeLocaldewrap = 3
};
