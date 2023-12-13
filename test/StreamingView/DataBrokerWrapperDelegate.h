//
//  DataBrokerWrapperDelegate.h
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/11/30.
//

#pragma once

#import "StreamingStatus.h"

@class DataBrokerWrapper;
@protocol DataBrokerWrapperDelegate<NSObject>

- (void)statusDidChange:(DataBrokerWrapper *)sender status:(StreamingStatus)status;
- (void)packetDidRetrieve:(DataBrokerWrapper *)sender packet:(TMediaDataPacketInfo *)packet;

@end
