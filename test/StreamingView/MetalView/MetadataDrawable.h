//
//  MetadataDrawable.h
//  iViewer
//
//  Created by davis.cho on 2018/3/8.
//  Copyright © 2018年 Vivotek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class Metadata;

@protocol MetadataDrawable <NSObject>

@required
@property (nonatomic) BOOL showMetadataID;
@property (nonatomic) BOOL showMetadataPositions;
@property (nonatomic) BOOL showMetadataTrackingBlock;
@property (nonatomic) BOOL showMetadataHeight;
@property (nonatomic) BOOL showMetadataTime;
@property (nonatomic) BOOL showMetadataGenderAge;

@required
- (void)didReceiveMetadata:(Metadata *)metadata;
- (void)drawMetadataObjectsWithOriginX:(NSInteger)originX originY:(NSInteger)originY centroidX:(NSInteger)centroidX centroidY:(NSInteger)centroidY height:(NSInteger)height timeStamp:(NSString *)timeStamp gid:(NSInteger)gid;
- (void)drawObjectWithCentroidPoint:(CGPoint)centroidPoint gid:(NSInteger)gid;
- (void)drawObjectIDWithCentroidPoint:(CGPoint)centroidPoint gid:(NSInteger)gid;
- (void)drawObjectPositionsWithCentroidPoint:(CGPoint)centroidPoint originPoint:(CGPoint)originPoint gid:(NSInteger)gid;
- (void)drawTrackingBlockWithTopPoint0:(CGPoint)topPoint0 topPoint1:(CGPoint)topPoint1 topPoint2:(CGPoint)topPoint2 topPoint3:(CGPoint)topPoint3 bottomPoint0:(CGPoint)bottomPoint0 bottomPoint1:(CGPoint)bottomPoint1 bottomPoint2:(CGPoint)bottomPoint2 bottomPoint3:(CGPoint)bottomPoint3;
- (void)drawTextLabelWithCentroidPoint:(CGPoint)centroidPoint text:(NSString *)text iconImage:(UIImage *)iconImage;
- (void)drawTextLabelsWithCentroidPoint:(CGPoint)centroidPoint gender:(NSInteger)gender age:(NSString *)age height:(NSInteger)height durationTime:(NSInteger)durationtime;
- (void)clearMetadataObjects;

@end
