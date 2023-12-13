//
//  GLViewportCtrWrapper.mm
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

#import "GLViewportCtrWrapper.h"
#include "GLViewportCtr.h"

@interface GLViewportCtrWrapper ()

@property (nonatomic) CGLViewportCtr viewportCtr;
@end

@implementation GLViewportCtrWrapper

- (void)initWithFramebufferW:(float)fFramebufferW framebufferH:(float)fFramebufferH textureW:(float)fTextureW textureH:(float)fTextureH
{
    _viewportCtr.Init(fFramebufferW, fFramebufferH, fTextureW, fTextureH);
}

- (void)reset
{
    _viewportCtr.Reset();
}

- (float)getFitTopBotScale
{
    return _viewportCtr.GetFitTopBotScale();
}

- (void)setScale:(float)fScale
{
    _viewportCtr.SetScale(fScale);
}

- (void)setScaleWithPivotX:(float)fPivotX pivotY:(float)fPivotY scale:(float)fScale
{
    _viewportCtr.SetScaleWithPivot(fPivotX, fPivotY, fScale);
}

- (void)setTranslateWithDeltaX:(float)fDeltaX deltaY:(float)fDeltaY
{
    _viewportCtr.SetTranslate(fDeltaX, fDeltaY);
}

- (void)setDefaultLocation
{
    _viewportCtr.SetDefaultLocation();
}

- (void)getShaderZoomVectorOfX:(float*)pfX Y:(float*)pfY W:(float*)pfW H:(float*)pfH
{
    _viewportCtr.GetShaderZoomVector(pfX, pfY, pfW, pfH);
}

@end
