//
//  GLViewportCtr.h
//
//  Created by SDK on 2017/03/20.
//  Copyright © 2017 Vivotek SDK. All rights reserved.
//

#ifndef _GL_VIEWPORT_CONTROL_H_
#define _GL_VIEWPORT_CONTROL_H_

#include "math.h"

#define VIEWPORT_MIN_SCALE 1.0f
#define VIEWPORT_MAX_SCALE 12.0f

typedef struct T_Viewport_Option
{
    float fLocationCx;
    float fLocationCy;
    float fSacle;
} TViewportOpt;

class CGLViewportCtr
{
public:
    
    CGLViewportCtr():
    m_bInit(false),
    m_fTextureW(0),
    m_fTextureH(0),
    m_fFramebufferW(0),
    m_fFramebufferH(0),
    m_fDisplayDefaultW(0),
    m_fDisplayDefaultH(0),
    m_bVertical(true),
    m_fViewportX(0),
    m_fViewportY(0),
    m_fViewportW(0),
    m_fViewportH(0),
    m_fScissorX(0),
    m_fScissorY(0),
    m_fScissorW(0),
    m_fScissorH(0),
    m_fScale(VIEWPORT_MIN_SCALE),
    m_bFitTopBot(false)
    {
        
    }
    
    ~CGLViewportCtr()
    {
        
    }
    
    void Init(float fFramebufferW, float fFramebufferH, float fTextureW, float fTextureH)
    {
        if (fFramebufferW <= 0 || fFramebufferH <= 0 || fTextureW <= 0 || fTextureH <= 0)
        {
            return;
        }
        
        if (fFramebufferW == m_fFramebufferW && fFramebufferH == m_fFramebufferH && fTextureW == m_fTextureW && fTextureH == m_fTextureH)
        {
            return;
        }
        
        // get current options
        TViewportOpt tRestoreOpt = {};
        GetViewportOption(&tRestoreOpt);
        
        m_fFramebufferW = fFramebufferW;
        m_fFramebufferH = fFramebufferH;
        m_fTextureW = fTextureW;
        m_fTextureH = fTextureH;
        
        // vertical
        float fAspectRatioF = fFramebufferW / fFramebufferH;
        float fAspectRatioT = fTextureW / fTextureH;
        m_bVertical = (fAspectRatioT >= fAspectRatioF);
        
        // set default parameters
        UpdateViewportWithDefaultValue();
        
        // restore
        SetViewportOption(&tRestoreOpt);
        
        m_bInit = true;
    }
    
    void Reset()
    {
        m_bInit = false;
        m_fTextureW = 0;
        m_fTextureH = 0;
        m_fFramebufferW = 0;
        m_fFramebufferH = 0;
        m_fDisplayDefaultW = 0;
        m_fDisplayDefaultH = 0;
        m_bVertical= true;
        m_fViewportX= 0;
        m_fViewportY= 0;
        m_fViewportW= 0;
        m_fViewportH= 0;
        m_fScissorX= 0;
        m_fScissorY= 0;
        m_fScissorW= 0;
        m_fScissorH= 0;
        m_fScale = VIEWPORT_MIN_SCALE;
        m_bFitTopBot = false;
    }
    
    //--------------------------------------------------------------------------------------------------
    // Fit the viewport height same as the framebuffer height
    void EnableFitTopBot()
    {
        if (m_bInit)
        {
            m_bFitTopBot = true;
            
            UpdateScale(GetFitTopBotScale());
            UpdateViewportByScale();
        }
    }
    
    void DisableFitTopBot()
    {
        if (m_bInit)
        {
            m_bFitTopBot = false;
            UpdateScale(VIEWPORT_MIN_SCALE);
            UpdateViewportByScale();
        }
    }
    
    float GetFitTopBotScale() const
    {
        return (m_bInit) ? ((m_fFramebufferH * m_fTextureW) / (m_fFramebufferW * m_fTextureH)) : VIEWPORT_MIN_SCALE;
    }
    //--------------------------------------------------------------------------------------------------
    void SetViewportOption(const TViewportOpt* ptOption)
    {
        if (ptOption && m_bInit)
        {
            UpdateScale(ptOption->fSacle);
            UpdateViewportByScale();
            
            float fViewportX = (m_fFramebufferW / 2) - m_fViewportW / 2 - ptOption->fLocationCx * m_fViewportW;
            float fViewportY = (m_fFramebufferH / 2) - m_fViewportH / 2 - ptOption->fLocationCy * m_fViewportH;
            
            m_fViewportX = GetCalibratedViewportX(fViewportX);
            m_fViewportY = GetCalibratedViewportY(fViewportY);
        }
    }
    
    void GetViewportOption(TViewportOpt* ptOption) const
    {
        if (ptOption && m_bInit)
        {
            ptOption->fLocationCx = GetIndicatorX();
            ptOption->fLocationCy = GetIndicatorY();
            ptOption->fSacle = m_fScale;
        }
    }
    //--------------------------------------------------------------------------------------------------
    // Zoom control
    void SetScale(float fScale)
    {
        if (m_fScale == fScale)
        {
            return;
        }
        
        if (!m_bFitTopBot)
        {
            UpdateScale(fScale);
            UpdateViewportByScale();
        }
    }
    
    void SetScaleWithPivot(float fPivotX, float fPivotY, float fScale)
    {
        if (m_fScale == fScale)
        {
            return;
        }
        
        if (!m_bFitTopBot)
        {
            UpdateScale(fScale);
            UpdateViewportByScaleWithPivot(fPivotX, fPivotY);
        }
    }
    
    // Pan / Tilt control
    void SetTranslate(float fDeltaX, float fDeltaY)
    {
        UpdateViewportByTranslate(fDeltaX, fDeltaY);
    }
    
    // Set the image center fit the framebuffer center
    void SetDefaultLocation()
    {
        UpdateViewportByCenterLoc(m_fFramebufferW / 2, m_fFramebufferH / 2);
    }
    //--------------------------------------------------------------------------------------------------
    bool GetViewport(float* pfX, float* pfY, float* pfW, float* pfH) const
    {
        if (!m_bInit || pfX == NULL || pfY == NULL || pfW == NULL || pfH == NULL)
        {
            return false;
        }
        
        *pfX = m_fViewportX;
        *pfY = m_fViewportY;
        *pfW = m_fViewportW;
        *pfH = m_fViewportH;
        return true;
    }
    
    bool GetShaderZoomVector(float* pfX, float* pfY, float* pfW, float* pfH) const
    {
        if (!m_bInit || pfX == NULL || pfY == NULL || pfW == NULL || pfH == NULL)
        {
            return false;
        }
        
        *pfX = -m_fViewportX / m_fViewportW;
        *pfY = -m_fViewportY / m_fViewportH;
        *pfW = m_fFramebufferW / m_fViewportW;
        *pfH = m_fFramebufferH / m_fViewportH;
        return true;
    }
    
    bool GetValidViewportRegion(int* piX, int* piY, int* piW, int* piH) const
    {
        if (!m_bInit || piX == NULL || piY == NULL || piW == NULL || piH == NULL)
        {
            return false;
        }
        
        float fX = 0, fY = 0, fW = 1, fH = 1;
        GetValidViewportRegion(&fX, &fY, &fW, &fH);
        
        *piX = (int)ceil(fX);
        *piY = (int)ceil(fY);
        *piW = (int)floor(fW);
        *piH = (int)floor(fH);
        
        return true;
    }
    
    bool GetScissor(bool bEnableScissor, float* pfX, float* pfY, float* pfW, float* pfH) const
    {
        if (!m_bInit || pfX == NULL || pfY == NULL || pfW == NULL || pfH == NULL)
        {
            return false;
        }
        
        if (bEnableScissor)
        {
            *pfX = m_fScissorX;
            *pfY = m_fScissorY;
            *pfW = m_fScissorW;
            *pfH = m_fScissorH;
        }
        else
        {
            *pfX = 0;
            *pfY = 0;
            *pfW = m_fFramebufferW;
            *pfH = m_fFramebufferH;
        }
        return true;
    }
    
    bool GetShaderScissorVector(bool bEnableScissor, float* pfX, float* pfY, float* pfW, float* pfH) const
    {
        if (!m_bInit || pfX == NULL || pfY == NULL || pfW == NULL || pfH == NULL)
        {
            return false;
        }
        
        if (bEnableScissor)
        {
            *pfX = m_fScissorX / m_fFramebufferW;
            *pfY = m_fScissorY / m_fFramebufferH;
            *pfW = m_fScissorW / m_fFramebufferW;
            *pfH = m_fScissorH / m_fFramebufferH;
        }
        else
        {
            *pfX = 0;
            *pfY = 0;
            *pfW = 1;
            *pfH = 1;
        }
        return true;
    }
    //--------------------------------------------------------------------------------------------------
    // Indicator current view location
    float GetIndicatorX() const // -0.5 ~ 0.5
    {
        return (m_bInit) ? (((m_fFramebufferW / 2) - (m_fViewportX + m_fViewportW / 2)) / m_fViewportW) : 0;
    }
    
    float GetIndicatorY() const // -0.5 ~ 0.5
    {
        return (m_bInit) ? (((m_fFramebufferH / 2) - (m_fViewportY + m_fViewportH / 2)) / m_fViewportH) : 0;
    }
    
    float GetIndicatorW() const // 0 ~ 1
    {
        if (!m_bInit || m_fFramebufferW >= m_fViewportW)
        {
            return 1.0;
        }
        return m_fFramebufferW / m_fViewportW;
    }
    
    float GetIndicatorH() const // 0 ~ 1
    {
        if (!m_bInit || m_fFramebufferH >= m_fViewportH)
        {
            return 1.0;
        }
        return m_fFramebufferH / m_fViewportH;
    }
    
    //--------------------------------------------------------------------------------------------------
private:
    bool  m_bInit;
    
    // Input texture size
    float m_fTextureW;
    float m_fTextureH;
    
    // Render target framebuffer size
    float m_fFramebufferW;
    float m_fFramebufferH;
    
    // Original display viewport size
    float m_fDisplayDefaultW;
    float m_fDisplayDefaultH;
    
    // Indicate the render target is vertical to texture
    // True for the aspect ratio of texture larger than the aspect ratio of framebuffer
    bool m_bVertical;
    
    // Indicate the display region on the framebuffer
    float m_fViewportX;
    float m_fViewportY;
    float m_fViewportW;
    float m_fViewportH;
    
    // Indicate the constrain display region on the framebuffer
    float m_fScissorX;
    float m_fScissorY;
    float m_fScissorW;
    float m_fScissorH;
    
    // Scale of zoom in and out. (1x ~ 12x)
    float m_fScale;
    
    // Keep image with its aspect ratio and scale it to fit the top and bottom of the framebuffer.
    bool m_bFitTopBot;
    
    //--------------------------------------------------------------------------------------------------
    // private functions
    float GetCalibratedViewportX(float fVx)
    {
        if (m_fViewportW > m_fFramebufferW)
        {
            if (fVx > 0)
            {
                return 0; // max x
            }
            else if (fVx < (m_fFramebufferW - m_fViewportW))
            {
                return (int)(m_fFramebufferW - m_fViewportW); // min x
            }
            
            return fVx;
        }
        else
        {
            // center alignment
            return m_fFramebufferW / 2 - m_fViewportW / 2;
        }
    }
    
    float GetCalibratedViewportY(float fVy)
    {
        if (m_fViewportH > m_fFramebufferH)
        {
            if (fVy > 0)
            {
                return 0; // min y
            }
            else if (fVy < (m_fFramebufferH - m_fViewportH))
            {
                return (int)(m_fFramebufferH - m_fViewportH); // max y
            }
            
            return fVy;
        }
        else
        {
            // center alignment
            return m_fFramebufferH / 2 - m_fViewportH / 2;
        }
    }
    
    void UpdateScale(float fScale)
    {
        if (!m_bInit)
        {
            return;
        }
        
        if (fScale < VIEWPORT_MIN_SCALE)
        {
            fScale = VIEWPORT_MIN_SCALE;
        }
        else if (fScale > VIEWPORT_MAX_SCALE)
        {
            fScale = VIEWPORT_MAX_SCALE;
        }
        
        m_fScale = fScale;
    }
    
    void UpdateViewportByScale()
    {
        if (!m_bInit)
        {
            return;
        }
        
        if (VIEWPORT_MIN_SCALE == m_fScale)
        {
            UpdateViewportWithDefaultValue();
        }
        
        float fNewW = m_fDisplayDefaultW * m_fScale;
        float fNewH = m_fDisplayDefaultH * m_fScale;
        
        float fCx = m_fViewportX + m_fViewportW / 2;
        float fCy = m_fViewportY + m_fViewportH / 2;
        
        m_fViewportX = fCx - fNewW / 2;
        m_fViewportY = fCy - fNewH / 2;
        m_fViewportW = fNewW;
        m_fViewportH = fNewH;
        
        // constrain value
        m_fViewportX = GetCalibratedViewportX(m_fViewportX);
        m_fViewportY = GetCalibratedViewportY(m_fViewportY);
    }
    
    void UpdateViewportByScaleWithPivot(float fPivotX, float fPivotY)
    {
        if (!m_bInit)
        {
            return;
        }
        
        if (VIEWPORT_MIN_SCALE == m_fScale)
        {
            UpdateViewportWithDefaultValue();
        }
        
        float fNewW = m_fDisplayDefaultW * m_fScale;
        float fNewH = m_fDisplayDefaultH * m_fScale;
        
        float fDx = (fPivotX - m_fViewportX) * fNewW / m_fViewportW;
        float fDy = (fPivotY - m_fViewportY) * fNewH / m_fViewportH;
        
        m_fViewportX = fPivotX - fDx;
        m_fViewportY = fPivotY - fDy;
        m_fViewportW = fNewW;
        m_fViewportH = fNewH;
        
        // constrain value
        m_fViewportX = GetCalibratedViewportX(m_fViewportX);
        m_fViewportY = GetCalibratedViewportY(m_fViewportY);
    }
    
    void UpdateViewportByTranslate(float fDeltaX, float fDeltaY)
    {
        if (!m_bInit)
        {
            return;
        }
        
        if (fDeltaX != 0 || fDeltaY != 0)
        {
            m_fViewportX += fDeltaX;
            m_fViewportY += fDeltaY;
            
            // constrain value
            m_fViewportX = GetCalibratedViewportX(m_fViewportX);
            m_fViewportY = GetCalibratedViewportY(m_fViewportY);
        }
    }
    
    void UpdateViewportByCenterLoc(float fCenterLocX, float fCenterLocY)
    {
        if (!m_bInit)
        {
            return;
        }
        
        m_fViewportX = GetCalibratedViewportX(fCenterLocX - m_fViewportW / 2);
        m_fViewportY = GetCalibratedViewportY(fCenterLocY - m_fViewportH / 2);
    }
    
    void UpdateViewportWithDefaultValue()
    {
        m_fScale = VIEWPORT_MIN_SCALE;
        m_bFitTopBot = false;
        
        if (m_bVertical)
        {
            m_fViewportW = m_fFramebufferW;
            m_fViewportH = m_fFramebufferW * m_fTextureH / m_fTextureW;
            
            m_fViewportX = 0;
            m_fViewportY = m_fFramebufferH / 2 - m_fViewportH / 2;
        }
        else
        {
            m_fViewportW = m_fFramebufferH * m_fTextureW / m_fTextureH;
            m_fViewportH = m_fFramebufferH;
            
            m_fViewportX = m_fFramebufferW / 2 - m_fViewportW / 2;
            m_fViewportY = 0;
        }
        
        m_fDisplayDefaultW = m_fViewportW;
        m_fDisplayDefaultH = m_fViewportH;
        
        m_fScissorX = m_fViewportX;
        m_fScissorY = m_fViewportY;
        m_fScissorW = m_fViewportW;
        m_fScissorH = m_fViewportH;
    }
    
    bool GetValidViewportRegion(float* pfX, float* pfY, float* pfW, float* pfH) const
    {
        if (!m_bInit || pfX == NULL || pfY == NULL || pfW == NULL || pfH == NULL)
        {
            return false;
        }
        
        *pfX = (m_fViewportX < 0) ? 0 : m_fViewportX;
        *pfY = (m_fViewportY < 0) ? 0 : m_fViewportY;
        *pfW = (m_fViewportW > m_fFramebufferW) ? m_fFramebufferW : m_fViewportW;
        *pfH = (m_fViewportH > m_fFramebufferH) ? m_fFramebufferH : m_fViewportH;
        
        return true;
    }
};


#endif /* _GL_VIEWPORT_CONTROL_H_ */
