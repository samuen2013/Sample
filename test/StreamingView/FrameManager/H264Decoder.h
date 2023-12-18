//
//  H264Decoder.h
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import "HWDecoderDelegate.h"

@interface H264Decoder : NSObject

@property (assign) id<HWDecoderDelegate> delegate;

- (SCODE)decodeFrame:(NSData *)frameData;

@end
