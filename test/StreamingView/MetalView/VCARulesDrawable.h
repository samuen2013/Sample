//
//  VCARulesDrawable.h
//  iViewer
//
//  Created by davis.cho on 2018/3/8.
//  Copyright © 2018年 Vivotek. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VCARulesDrawable <NSObject>

@required
@property (nonatomic) BOOL showVCARules;
@property (nonatomic) BOOL showVCAName;
@property (nonatomic) BOOL showVCADirection;
@property (nonatomic) BOOL showVCAExclusiveArea;

@required
- (void)drawVCARules:(NSDictionary *)rules;
- (void)drawRuleName:(NSString *)name onRect:(CGRect)rect;
- (void)drawZoneDetectionWithName:(NSString *)name points:(NSArray *)points;
- (void)drawExclusiveAreaWithPoints:(NSArray *)points;
- (void)drawDirectionWithCentroidPoint:(CGPoint)centroidPoint directionText:(NSString *)directionText;
- (void)drawCountingWithName:(NSString *)name direction:(NSString *)direction point0:(CGPoint)point0 point1:(CGPoint)point1 point2:(CGPoint)point2;
- (void)drawFlowPathCountingWithName:(NSString *)name direction:(NSString *)direction points:(NSArray *)points;
- (void)clearVCARules;

@end
