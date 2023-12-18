//
//  HWDecoderDelegate.h
//  test
//
//  Created by 曹盛淵 on 2023/12/18.
//

#ifndef HWDecoderDelegate_h
#define HWDecoderDelegate_h

@protocol HWDecoderDelegate <NSObject>

- (void)didDecodeWithImageBuffer:(CVImageBufferRef)imageBuffer;

@end

#endif /* HWDecoderDelegate_h */
