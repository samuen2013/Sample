#ifndef _VIDEODECODER_H_
#define _VIDEODECODER_H_

#include <boost/thread/mutex.hpp>

#ifdef __cplusplus
extern "C" {
#endif
#undef AVMediaType
#define AVMediaType FFMpeg_AVMediaType
#include <libavcodec/avcodec.h>
#undef AVMediaType
#define AVMediaType Cocoa_AVMediaType
#include <AVFoundation/AVFoundation.h>
#undef AVMediaType
#ifdef __cplusplus
}
#endif

#include <mach/mach_host.h>

static boost::mutex g_CodecInitMutex;

class VideoDecoder
{
public:

    static void Init()
	{
		//avcodec_init();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		avcodec_register_all();
#pragma clang diagnostic pop
	}
    
    unsigned int countCores()
    {
        host_basic_info_data_t hostInfo;
        mach_msg_type_number_t infoCount;
        
        infoCount = HOST_BASIC_INFO_COUNT;
        host_info(mach_host_self(), HOST_BASIC_INFO,
                  (host_info_t)&hostInfo, &infoCount);
        
        return (unsigned int)(hostInfo.max_cpus);
    }

	VideoDecoder(DWORD dwStreamType)
	{
		boost::mutex::scoped_lock lock(g_CodecInitMutex);
		
		if (dwStreamType == mctMP4V)
		{
			pCodec = avcodec_find_decoder(AV_CODEC_ID_MPEG4);
		}
		else if (dwStreamType == mctJPEG)
		{
			pCodec = avcodec_find_decoder(AV_CODEC_ID_MJPEG);
		}
		else if (dwStreamType == mctH264)
		{
			pCodec = avcodec_find_decoder(AV_CODEC_ID_H264);
		}
        else if (dwStreamType == mctHEVC)
        {
            pCodec = avcodec_find_decoder(AV_CODEC_ID_H265);
        }
		else
		{
			assert(false&&"video codec not support");
			fprintf(stderr, "Video codec not support !\n");
		}

		if(pCodec == NULL) 
		{
			assert(false&&"Unsupported video codec");
			fprintf(stderr, "Unsupported video codec!\n");
		}
        
		pCodecCtxt = avcodec_alloc_context3(pCodec);
        
        if (pCodec->capabilities&AV_CODEC_CAP_FRAME_THREADS)
        {
            unsigned int cores = countCores();
            
            if (cores > 1)
            {
                pCodecCtxt->thread_count = 2;
            }
            else
            {
                pCodecCtxt->thread_count = 1;
            }
            
            if (pCodec->capabilities&AV_CODEC_CAP_SLICE_THREADS)
            {
                pCodecCtxt->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
            }
            else
            {
                pCodecCtxt->thread_type = FF_THREAD_FRAME;
            }
        }
        
        retryCount = 0;
        while (avcodec_open2(pCodecCtxt, pCodec, NULL) < 0 && retryCount < 10)
        {
            fprintf(stderr, "avcodec_open error!\n");
            pCodecCtxt->thread_count = 1;
            retryCount++;
            
            sleep(30);
        }
	};

	~VideoDecoder()
	{
        boost::mutex::scoped_lock lock(g_CodecInitMutex);
        
		// Close the codec
        if (pCodecCtxt)
        {
            avcodec_close(pCodecCtxt);
            av_free(pCodecCtxt);
        }
	};

	int  Decode(TMediaDataPacketInfo* ptMediaDataPacket,  AVFrame *pFrame)
	{
		int nFrameFinished = 0;
        
        AVPacket avpkt;
        av_init_packet(&avpkt);
        
		//avcodec_decode_video(pCodecCtxt, pFrame, &nFrameFinished, ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset, ptMediaDataPacket->dwBitstreamSize);
        
        avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
        avpkt.size = ptMediaDataPacket->dwBitstreamSize;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        avcodec_decode_video2(pCodecCtxt, pFrame, &nFrameFinished, &avpkt);
#pragma clang diagnostic pop
		
        return nFrameFinished;
	};

	AVCodecContext* GetCodecContext()
	{
        return pCodecCtxt;
	}

protected:
	AVCodec *pCodec;
	AVCodecContext *pCodecCtxt;
    int retryCount;
};

#endif // _VIDEODECODER_H_
