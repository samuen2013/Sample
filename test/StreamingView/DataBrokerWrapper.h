//
//  DataBrokerWrapper.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/8/26.
//

#import "DataBrokerWrapperDelegate.h"

@interface DataBrokerWrapper : NSObject

@property (assign) id<DataBrokerWrapperDelegate> delegate;

- (void)startLiveStreaming:(NSString *)ip port:(NSInteger)port streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex;
- (void)startNVRLiveStreaming:(NSString *)ip port:(NSInteger)port streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex;
- (void)startPlaybackStreaming:(NSString *)ip port:(NSInteger)port startTime:(NSTimeInterval)startTime isFusion:(BOOL)isFusion;
- (void)startPlaybackStreaming:(NSString *)ip port:(NSInteger)port startTime:(NSTimeInterval)startTime streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex;
- (void)changeSpeed:(float)speed;
- (void)seekTo:(NSTimeInterval)timestamp;
- (void)stopStreaming;
- (void)pause;
- (void)resume;
- (void)releaseHandling;

@end
