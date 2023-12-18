//
//  H265Decoder.h
//  test
//
//  Created by 曹盛淵 on 2023/12/18.
//

#ifndef H265Decoder_h
#define H265Decoder_h

#import "HWDecoderDelegate.h"

@interface H265Decoder : NSObject

@property (assign) id<HWDecoderDelegate> delegate;

- (SCODE)decodeFrame:(NSData *)frameData;

@end

#endif /* H265Decoder_h */
