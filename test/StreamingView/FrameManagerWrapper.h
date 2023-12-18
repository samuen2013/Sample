//
//  FrameManagerWrapper.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/11/30.
//

#import "FrameManagerWrapperDelegate.h"
#import "FrameManager/HWDecoderDelegate.h"
#import "FrameManager/RemoteIOPlayer.h"

@interface FrameManagerWrapper : NSObject<HWDecoderDelegate, RemoteIOPlayerDelegate>

@property (assign) id<FrameManagerWrapperDelegate> delegate;

- (void)releaseAll;
- (void)cleanBuffer;
- (void)inputPacket:(TMediaDataPacketInfo *)packet;
- (void)pause;
- (void)resume;
- (void)enableAudio;
- (void)disableAudio;
- (void)setSpeed:(float)speed;
- (void)setUseRecordingTime:(bool)useRecordingTime;

@end
