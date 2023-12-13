//
//  GLViewportCtrWrapper.h
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GLViewportCtrWrapper : NSObject

- (void)initWithFramebufferW:(float)fFramebufferW framebufferH:(float)fFramebufferH textureW:(float)fTextureW textureH:(float)fTextureH;
- (void)reset;
- (float)getFitTopBotScale;
- (void)setScale:(float)fScale;
- (void)setScaleWithPivotX:(float)fPivotX pivotY:(float)fPivotY scale:(float)fScale;
- (void)setTranslateWithDeltaX:(float)fDeltaX deltaY:(float)fDeltaY;
- (void)setDefaultLocation;
- (void)getShaderZoomVectorOfX:(float*)pfX Y:(float*)pfY W:(float*)pfW H:(float*)pfH;

@end
