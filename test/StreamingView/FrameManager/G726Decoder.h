#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Float11 {
    uint8_t sign;   /**< 1bit sign */
    uint8_t exp;    /**< 4bit exponent */
    uint8_t mant;   /**< 6bit mantissa */
} Float11;

typedef struct G726Tables {
    const int* quant;         /**< quantization table */
    const int16_t* iquant;    /**< inverse quantization table */
    const int16_t* W;         /**< special table #1 ;-) */
    const uint8_t* F;         /**< special table #2 */
} G726Tables;

typedef struct G726Context {
    void *av_class;
    G726Tables tbls;    /**< static tables needed for computation */

    Float11 sr[2];      /**< prev. reconstructed samples */
    Float11 dq[6];      /**< prev. difference */
    int a[2];           /**< second order predictor coeffs */
    int b[6];           /**< sixth order predictor coeffs */
    int pk[2];          /**< signs of prev. 2 sez + dq */

    int ap;             /**< scale factor control */
    int yu;             /**< fast scale factor */
    int yl;             /**< slow scale factor */
    int dms;            /**< short average magnitude of F[i] */
    int dml;            /**< long average magnitude of F[i] */
    int td;             /**< tone detect */

    int se;             /**< estimated signal for the next iteration */
    int sez;            /**< estimated second order prediction */
    int y;              /**< quantizer scaling factor for the next iteration */
    int code_size;
} G726Context;
    

int16_t g726_decode(G726Context* c, int I);
int g726_reset(G726Context *c);

#ifdef __cplusplus
}
#endif

typedef struct  {
    uint8_t* data;
    DWORD size;
} EncodeData;


class G726Decoder
{
public:
    
	G726Decoder(bool byG726Pack, int nBits_per_coded_sample):
    m_byG726Pack(byG726Pack),
    m_nBits_per_coded_sample(nBits_per_coded_sample)
	{
		G726Context *c = &priv_data;
        
		memset(c, 0, sizeof(G726Context));
        
		c->code_size = m_nBits_per_coded_sample;
        
		g726_reset(c);
	}
    
    
    SCODE  decode_audio(BYTE* audio_buf, int* frame_size_ptr, const EncodeData* pkt)
    {
        if (m_byG726Pack)
        {
            return decode_audio1(audio_buf, frame_size_ptr, pkt);
        }
        else
        {
            return decode_audio2(audio_buf, frame_size_ptr, pkt);
        }
    }
    
	
private:
    
    SCODE  decode_audio1(BYTE* audio_buf, int* frame_size_ptr, const EncodeData* pkt)
	{
		G726Context *c = &priv_data;
        
		DWORD out_samples = pkt->size * 8 / m_nBits_per_coded_sample;
        
		if (*frame_size_ptr < out_samples)
		{
			return S_FAIL;
		}
        
		*frame_size_ptr = out_samples * sizeof(int16_t);
        
		int16_t *samples = (int16_t *)audio_buf;
        
		VVTK::SDK::Utility::BitstreamReader gb(pkt->data, pkt->size);
        
		while (out_samples--)
        {
            if (m_nBits_per_coded_sample == 2)
            {
                *samples++ = g726_decode(c, gb.GetBits<2>());
            }
            else if (m_nBits_per_coded_sample == 3)
            {
                *samples++ = g726_decode(c, gb.GetBits<3>());
            }
            else if (m_nBits_per_coded_sample == 4)
            {
                *samples++ = g726_decode(c, gb.GetBits<4>());
            }
            else if (m_nBits_per_coded_sample == 5)
            {
                *samples++ = g726_decode(c, gb.GetBits<5>());
            }
        }
		return S_OK;
	}
    
    SCODE decode_audio2(BYTE* audio_buf, int* frame_size_ptr, const EncodeData* pkt)
	{
		G726Context *c = &priv_data;
        
		DWORD out_samples = pkt->size * 8 / m_nBits_per_coded_sample;
        
		if (*frame_size_ptr < out_samples)
		{
			return S_FAIL;
		}
        
		*frame_size_ptr = out_samples * sizeof(int16_t);
        
		int16_t *samples = (int16_t *)audio_buf;
        
		BYTE in[8] = "";
        
		for (const BYTE *it = pkt->data, *end = pkt->data + pkt->size; it < end; it += m_nBits_per_coded_sample)
		{
			UnpackCodeword(m_nBits_per_coded_sample, it, in);
            
			*samples++ = g726_decode(c, in[0]);
			*samples++ = g726_decode(c, in[1]);
			*samples++ = g726_decode(c, in[2]);
			*samples++ = g726_decode(c, in[3]);
			*samples++ = g726_decode(c, in[4]);
			*samples++ = g726_decode(c, in[5]);
			*samples++ = g726_decode(c, in[6]);
			*samples++ = g726_decode(c, in[7]);
		}
        
		return S_OK;
	}
    
    void UnpackCodeword(int bps, const BYTE* inCode, BYTE (&outCode)[8])
    {
        if (bps == 2)
        {
            outCode[3] = (BYTE)(((inCode[0] >> 6) & 0x3));
            outCode[2] = (BYTE)(((inCode[0] >> 4) & 0x3));
            outCode[1] = (BYTE)(((inCode[0] >> 2) & 0x3));
            outCode[0] = (BYTE)((inCode[0] & 0x3));
            outCode[7] = (BYTE)(((inCode[1] >> 6) & 0x3));
            outCode[6] = (BYTE)(((inCode[1] >> 4) & 0x3));
            outCode[5] = (BYTE)(((inCode[1] >> 2) & 0x3));
            outCode[4] = (BYTE)((inCode[1] & 0x3));
        }
        else if (bps == 3)
        {
            outCode[0] = (BYTE)((inCode[0] & 0x7));
            outCode[1] = (BYTE)((inCode[0] >> 3) & 0x7);
            outCode[2] = (BYTE)(((inCode[0] >> 6) & 0x3) | ((inCode[1] & 0x1))<<2);
            outCode[3] = (BYTE)((inCode[1] >> 1) & 0x7);
            outCode[4] = (BYTE)((inCode[1] >> 4) & 0x7);
            outCode[5] = (BYTE)(((inCode[1] >> 7) & 0x1) | (inCode[2] & 0x3)<<1);
            outCode[6] = (BYTE)((inCode[2] >> 2) & 0x7);
            outCode[7] = (BYTE)((inCode[2] >> 5) & 0x7);
            
        }
        else if (bps == 4)
        {
            outCode[1] = (BYTE)(((inCode[0] >> 4) & 0xf));
            outCode[0] = (BYTE)((inCode[0] & 0xf));
            outCode[3] = (BYTE)(((inCode[1] >> 4) & 0xf));
            outCode[2] = (BYTE)((inCode[1] & 0xf));
            outCode[5] = (BYTE)(((inCode[2] >> 4) & 0xf));
            outCode[4] = (BYTE)((inCode[2] & 0xf));
            outCode[7] = (BYTE)(((inCode[3] >> 4) & 0xf));
            outCode[6] = (BYTE)((inCode[3] & 0xf));
        }
        else if (bps == 5)
        {
            outCode[0] = (BYTE)((inCode[0] & 0x1f));
            outCode[1] = (BYTE)(((inCode[0] >> 5) & 0x7) | ((inCode[1] & 0x3)<<3));
            outCode[2] = (BYTE)((inCode[1] >> 2) & 0x1f);
            outCode[3] = (BYTE)(((inCode[1] >> 7) & 0x1) | ((inCode[2] & 0xf)<<1));
            outCode[4] = (BYTE)(((inCode[2] >> 4) & 0xf) | ((inCode[3] & 0x1)<<4));
            outCode[5] = (BYTE)((inCode[3] >> 1) & 0x1f);
            outCode[6] = (BYTE)(((inCode[3] >> 6) & 0x3) | ((inCode[4] & 0x7)<<2));
            outCode[7] = (BYTE)((inCode[4]  >>3) & 0x1f);
        }
    };
    
	G726Context priv_data;
    int m_nBits_per_coded_sample;
    int m_byG726Pack;
};
