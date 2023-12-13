//
//  HWDecoder.h
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@protocol HWDecoderDelegate <NSObject>
- (void)didDecodeWithImageBuffer:(CVImageBufferRef)imageBuffer;
@end

@interface HWDecoder : NSObject

@property (assign) id<HWDecoderDelegate> delegate;

- (OSStatus)createVideoFormatDescriptionForH264WithSPSData:(NSData *)spsData ppsData:(NSData *)ppsData;
- (OSStatus)createDecompressionSession;
- (OSStatus)decodeWithBytes:(Byte *)data length:(int)dataLength;

@end
