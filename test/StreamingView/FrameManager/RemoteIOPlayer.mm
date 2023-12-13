//
//  RemoteIOPlayer.m
//  RemoteIOTest
//
//

#import "RemoteIOPlayer.h"
#import <MediaPlayer/MediaPlayer.h>

#define MAX_AUDIO_FRAME_SIZE 192000
#define kOutputBus 0
#define kInputBus 1

#define FrameManager_Stream_Exit -2
#define FrameManager_Stream_Pause -3

@implementation RemoteIOPlayer
@synthesize	m_pbyTemBuff, m_pbyBuff, m_iBuffSize, m_bExit, m_bAudioCallbackExit;

- (id)init
{
    self = [super init];
    if (self)
    {
        BOOL success = NO;
        NSError *error = nil;
        if (![[[AVAudioSession sharedInstance] category] isEqual:AVAudioSessionCategoryPlayAndRecord]) {
            AVAudioSession *session = [AVAudioSession sharedInstance];
            success = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
            NSLog(@"RemoteIOPlayer AVAudioSession = %d",success);
            if (!success) {
                NSLog(@"%@ Error setting category: %@",
                      NSStringFromSelector(_cmd), [error localizedDescription]);
            }
        }
        
        [[MPRemoteCommandCenter sharedCommandCenter].togglePlayPauseCommand addTarget:self action:@selector(handleOnTooglePlayPause:)];
    }
    
    return self;
}

- (OSStatus)start
{
	m_bExit = false;
	m_bAudioCallbackExit = false;
	OSStatus status = AudioOutputUnitStart(audioUnit);
    
    if (status != kAudioServicesNoError)
    {
        NSLog(@"RemoteIOPlayer start Debug Log - status: %ld", (signed long)status);
    }
	return status;
}

- (MPRemoteCommandHandlerStatus)handleOnTooglePlayPause:(MPRemoteCommandEvent *)event
{
    NSLog(@"MPRemoteCommandCenter togglePlayPauseCommand");
    m_bAudioCallbackExit = true;
    return MPRemoteCommandHandlerStatusSuccess;
}

- (OSStatus)stop
{	
	
	m_bExit = true;
    
    int i = 100;
	
	while (i != 0)
	{
		if (m_bAudioCallbackExit)
		{
			break;
		}
        
        i--;
		usleep(1000);
	}
	
	OSStatus status = AudioOutputUnitStop(audioUnit);
	
	return status;
}


- (void)cleanUp
{
	AudioUnitUninitialize(audioUnit);
	delete [] m_pbyTemBuff;
	delete [] m_pbyBuff;
}

- (void)dealloc 
{
    [[MPRemoteCommandCenter sharedCommandCenter].togglePlayPauseCommand removeTarget:self];
	[super dealloc];
}

/* Parameters on entry to this function are :-
 
 *inRefCon - used to store whatever you want, can use it to pass in a reference to an objectiveC class
			 i do this below to get at the InMemoryAudioFile object, the line below :
				callbackStruct.inputProcRefCon = self;
			 in the initialiseAudio method sets this to "self" (i.e. this instantiation of RemoteIOPlayer).
			 This is a way to bridge between objectiveC and the straight C callback mechanism, another way
			 would be to use an "evil" global variable by just specifying one in theis file and setting it
			 to point to inMemoryAudiofile whenever it is set.
 
 *inTimeStamp - the sample time stamp, can use it to find out sample time (the sound card time), or the host time
 
 inBusnumber - the audio bus number, we are only using 1 so it is always 0 
 
 inNumberFrames - the number of frames we need to fill. In this example, because of the way audioformat is
				  initialised below, a frame is a 32 bit number, comprised of two signed 16 bit samples.
 
 *ioData - holds information about the number of audio buffers we need to fill as well as the audio buffers themselves */

static OSStatus playbackCallback(void *inRefCon, 
								 AudioUnitRenderActionFlags *ioActionFlags, 
								 const AudioTimeStamp *inTimeStamp, 
								 UInt32 inBusNumber, 
								 UInt32 inNumberFrames, 
								 AudioBufferList *ioData) 
{  	
	RemoteIOPlayer* pRenderer =  (RemoteIOPlayer*) inRefCon;
    
	if(pRenderer->m_bExit)
	{
	   pRenderer->m_bAudioCallbackExit = true;
	   return noErr;
	}
	
	//get the buffer to be filled
	AudioBuffer buffer = ioData->mBuffers[0];
	uint8_t* frameBuffer = (uint8_t *) buffer.mData;
	
	while (pRenderer->m_iBuffSize < buffer.mDataByteSize)
	{
		int	nInputAudioBufSize = MAX_AUDIO_FRAME_SIZE;
		
        auto scRet = [pRenderer.delegate didDecodeWithAudioBuffer:pRenderer->m_pbyTemBuff audioBufSize:&nInputAudioBufSize];
        if (scRet == FrameManager_Stream_Exit) {
            return noErr;
        } else if (scRet != S_OK) {
            //NSLog(@"Audio decode error, reset buffer to 0");
            
            for (int i = 0 ; i < buffer.mDataByteSize ; i++) {
                frameBuffer[i] = 0;
            }
            
            return noErr;
        }
        
        if(pRenderer->m_bExit) {
            pRenderer->m_bAudioCallbackExit = true;
            return noErr;
        }
			
		memcpy(pRenderer->m_pbyBuff + pRenderer->m_iBuffSize, pRenderer->m_pbyTemBuff, nInputAudioBufSize);
		pRenderer->m_iBuffSize += nInputAudioBufSize;					
	}
	
	for (int i = 0 ; i < buffer.mDataByteSize ; i++) {
		frameBuffer[i] = pRenderer->m_pbyBuff[i];
	}
	
    if (pRenderer->m_iBuffSize > buffer.mDataByteSize) {
		memmove(pRenderer->m_pbyBuff, pRenderer->m_pbyBuff + buffer.mDataByteSize, pRenderer->m_iBuffSize - buffer.mDataByteSize);
		pRenderer->m_iBuffSize = pRenderer->m_iBuffSize - buffer.mDataByteSize;
    } else {
        pRenderer->m_iBuffSize = 0;
    }
	
	return noErr;
}

AudioStreamBasicDescription createAudioFormat(uint32_t sampleRate, uint32_t codecType, uint32_t channels) {
    AudioStreamBasicDescription destFormat;
    bzero(&destFormat, sizeof(AudioStreamBasicDescription));
    
    destFormat.mSampleRate = sampleRate;
    destFormat.mFormatID = kAudioFormatLinearPCM;
    
    if (codecType == mctG711 || codecType == mctG711A || codecType == mctG726)
    {
        destFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        destFormat.mBitsPerChannel = 16;
    }
    else if (codecType == mctAAC || codecType == mctSAMR)
    {
        destFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        destFormat.mBitsPerChannel = 32;
    }
    else
    {
        assert(false&&"audio codec not support");
    }
    
    destFormat.mFramesPerPacket  = 1;
    destFormat.mChannelsPerFrame = channels;
    destFormat.mBytesPerFrame = destFormat.mBitsPerChannel / 8 * destFormat.mChannelsPerFrame;
    destFormat.mBytesPerPacket = destFormat.mBytesPerFrame * destFormat.mFramesPerPacket ;
    
    return destFormat;
}

- (OSStatus)intialiseAudio:(uint32_t)nCodecType : (uint32_t)nSampleRate : (uint32_t)nChannels
{
	m_iBuffSize = 0;
	m_pbyTemBuff = new uint8_t[MAX_AUDIO_FRAME_SIZE];
	m_pbyBuff = new uint8_t[MAX_AUDIO_FRAME_SIZE];
	
	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio units
    OSStatus status = AudioComponentInstanceNew(inputComponent, &audioUnit);
	
	UInt32 flag = 1;
	// Enable IO for playback
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, 
								  kAudioUnitScope_Output, 
								  kOutputBus,
								  &flag, 
								  sizeof(flag));
	
	// Describe format
    AudioStreamBasicDescription audioFormat = createAudioFormat(nSampleRate, nCodecType, nChannels);
	
	//Apply format
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Input, 
								  kOutputBus, 
								  &audioFormat, 
								  sizeof(audioFormat));
		

	// Set up the playback  callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = playbackCallback;
	//set the reference to "self" this becomes *inRefCon in the playback callback
	callbackStruct.inputProcRefCon = self;
	
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_SetRenderCallback, 
								  kAudioUnitScope_Global, 
								  kOutputBus,
								  &callbackStruct, 
								  sizeof(callbackStruct));
	
	// Initialise
	status = AudioUnitInitialize(audioUnit);
    
    if (status != kAudioServicesNoError)
    {
        NSLog(@"RemoteIOPlayer intialiseAudio Debug Log - status: %ld", (signed long)status);
    }
    return status;
}

@end
