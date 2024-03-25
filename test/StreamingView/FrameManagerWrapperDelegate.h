//
//  FrameManagerWrapperDelegate.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/11/30.
//

#pragma once

#import "StreamingStatus.h"
#import "MetalView/EAGLView.h"

@class Metadata;
@protocol FrameManagerWrapperDelegate<NSObject>

- (void)didChangeStreamingTimestamp:(unsigned long)timestamp;
- (void)didChangeFisheyeMountType:(FisheyeMountType)type;
- (void)didChangeFisheyeDewrapType:(EFisheyeDewarpType)type;
- (void)didChangeFisheyeRenderInfo:(TRenderInfo)info;
- (void)didChangeFisheyeRenderType:(ERenderType)type;
- (void)didChangeStreamingVideoCodec:(StreamingVideoCodec)streamingVideoCodec;
- (void)didReceiveUnsupportedVideoCodec;
- (void)didReceiveMetadata:(Metadata *)metadata;
- (void)didDecodeWithImageBuffer:(CVImageBufferRef)imageBuffer;
- (void)didDecodeWithAVFrame:(AVFrame *)avFrame width:(CGFloat)width height:(CGFloat)height pixelFormat:(enum AVPixelFormat)pixelFormat;

@end
