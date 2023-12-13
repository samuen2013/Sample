//
//  EAGLViewProtocol.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/9/24.
//

#ifndef EAGLViewProtocol_h
#define EAGLViewProtocol_h

@class ProjectModel;
@protocol EAGLViewProtocol <NSObject>

@required
@property (weak, nonatomic) id<EAGLViewDelegate> eaglViewDelegate;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UILabel *debugLabel;
@property (nonatomic, strong) ProjectModel *projectModel;

@required
- (void)renderWithCVImageBuffer:(CVImageBufferRef)imageBuffer;
- (void)renderWithAVFrame:(AVFrame *)frame width:(uint)width height:(uint)height pixelFormat:(enum AVPixelFormat)pixelFormat;
- (void)clear;
- (void)setScaleWithX:(double)x Y:(double)y;
- (void)setScaleWithDeltaX:(double)deltaX; // for fisheye
- (float)getScale;
- (void)resetScale;
- (void)setLocationWithX:(double)x Y:(double)y;
- (void)setLocationWithPoints:(double)dBegX begY:(double)dBegY endX:(double)dEndX endY:(double)dEndY; // for fisheye
- (void)setGestureEndPanbEnd:(bool)isEnd;
- (void)resetLocation;
- (CGSize)renderSize;
- (UIImage *)snapUIImage;
- (void)setRenderType:(ERenderType)renderType;
- (ERenderType)getRenderType;
- (bool)isFisheyeDewarping;
- (void)setFisheyeDewarpType:(NSInteger)dewarpType;
- (EFisheyeDewarpType)getFisheyeDewarpType;
- (void)setEnableFisheyeTransition:(bool)enableFisheyeTransition;
- (NSDictionary *)fisheyePTZLocation; // for fisheye
- (void)setRenderInfo:(TRenderInfo)renderInfo;
- (void)setKeepAspectRatiobKeep:(bool)isKeep;
- (void)fitScreenHeightWithPivotX:(float)fX Y:(float)fY;
- (void)setFisheyeMountType:(FisheyeMountType)mountType;

@end

#endif /* EAGLViewProtocol_h */
