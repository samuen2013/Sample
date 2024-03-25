#pragma once

#import "HWDecoderDelegate.h"

@interface H264Decoder : NSObject

@property (assign) id<HWDecoderDelegate> delegate;

- (SCODE)decodeFrame:(NSData *)frameData;

@end
