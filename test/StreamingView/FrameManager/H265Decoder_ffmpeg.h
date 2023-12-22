//
//  H265Decoder_ffmpeg.h
//  test
//
//  Created by 曹盛淵 on 2023/12/21.
//

#ifndef H265Decoder_ffmpeg_h
#define H265Decoder_ffmpeg_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

#undef AVMediaType
#define AVMediaType FFMpeg_AVMediaType
#include <libavcodec/avcodec.h>
#undef AVMediaType

#ifdef __cplusplus
}
#endif

enum AVPixelFormat hw_pix_fmt;
static enum AVPixelFormat get_hw_format(AVCodecContext *ctx, const enum AVPixelFormat *pix_fmts)
{
    const enum AVPixelFormat *p;

    for (p = pix_fmts; *p != -1; p++) {
        if (*p == hw_pix_fmt)
            return *p;
    }

    fprintf(stderr, "Failed to get HW surface format.\n");
    return AV_PIX_FMT_NONE;
}

class H265DecoderFFMpeg
{
public:
    H265DecoderFFMpeg() {
    }
    
    ~H265DecoderFFMpeg() {
        if (pCodecCtxt)
        {
            avcodec_close(pCodecCtxt);
            av_free(pCodecCtxt);
        }
        if (hw_device_ctx) {
            av_buffer_unref(&hw_device_ctx);
        }
    }
    
    int InitDecoder()
    {
        pCodec = avcodec_find_decoder(AV_CODEC_ID_HEVC);
        if (pCodec == NULL) {
            fprintf(stderr, "Video codec not support !\n");
            return -1;
        }
        for (auto i = 0; ; i++) {
            auto config = avcodec_get_hw_config(pCodec, i);
            if (!config) {
                fprintf(stderr, "Decoder %s does not support device type %s.\n",
                        pCodec->name, av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX));
                return -1;
            }
            if (config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX && config->device_type == AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
                hw_pix_fmt = config->pix_fmt;
                break;
            }
        }
        if (!(pCodecCtxt = avcodec_alloc_context3(pCodec))) {
            return AVERROR(ENOMEM);
        }
        pCodecCtxt->get_format = get_hw_format;
        
        auto ret = av_hwdevice_ctx_create(&hw_device_ctx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, NULL, NULL, 0);
        if (ret < 0) {
            fprintf(stderr, "av_hwdevice_ctx_create failed, %d\n", ret);
            return ret;
        }
        pCodecCtxt->hw_device_ctx = av_buffer_ref(hw_device_ctx);
        
        ret = avcodec_open2(pCodecCtxt, pCodec, NULL);
        if (ret < 0) {
            fprintf(stderr, "avcodec_open2 failed, %d\n", ret);
            return -1;
        }
        
        return 0;
    }
    
    int Decode(TMediaDataPacketInfo* ptMediaDataPacket, AVFrame *pFrame)
    {
        AVPacket avpkt;
        av_init_packet(&avpkt);
        avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
        avpkt.size = ptMediaDataPacket->dwBitstreamSize;
        
        auto ret = avcodec_send_packet(pCodecCtxt, &avpkt);
        if (ret != 0) {
            fprintf(stderr, "avcodec_send_packet failed, %d\n", ret);
            return ret;
        }
        
        ret = avcodec_receive_frame(pCodecCtxt, pFrame);
        if (ret != 0) {
            fprintf(stderr, "avcodec_receive_frame failed, %d\n", ret);
            return ret;
        }
        return 0;
    }
    
    AVCodecContext* GetCodecContext()
    {
        return pCodecCtxt;
    }
    
private:
    AVBufferRef *hw_device_ctx = NULL;
    
    AVCodec *pCodec = NULL;
    AVCodecContext *pCodecCtxt = NULL;
};


#endif /* H265Decoder_ffmpeg_h */
