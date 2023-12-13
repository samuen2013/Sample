//
//  RemoteIOPlayer.h
//  RemoteIOTest
//
//  Created by Aran Mulholland on 3/03/09.
//  Copyright 2009 Aran Mulholland. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioUnit/AudioUnit.h>

@protocol RemoteIOPlayerDelegate<NSObject>

- (SCODE)didDecodeWithAudioBuffer:(uint8_t *)audioBuffer audioBufSize:(int *)audioBufSize;

@end

@interface RemoteIOPlayer : NSObject 
{	
	AudioComponentInstance audioUnit;
	uint8_t* m_pbyTemBuff;
	uint8_t* m_pbyBuff; 
	uint32_t m_iBuffSize;
	bool m_bExit;
	bool m_bAudioCallbackExit;
}

@property (assign) id<RemoteIOPlayerDelegate> delegate;

@property (nonatomic, assign, readonly) uint8_t* m_pbyTemBuff;
@property (nonatomic, assign, readonly) uint8_t* m_pbyBuff;
@property (nonatomic) uint32_t m_iBuffSize;
@property (nonatomic) bool m_bExit;
@property (nonatomic) bool m_bAudioCallbackExit;

- (OSStatus)start;
- (OSStatus)stop;
- (void)cleanUp;
- (OSStatus)intialiseAudio: (uint32_t)nCodecType : (uint32_t)nSampleRate : (uint32_t)nChannels;

@end


