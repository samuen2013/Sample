//
//  NSData+Hex.h
//  test
//
//  Created by davis.cho on 2015/9/30.
//  Copyright © 2015年 demon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Hex)
- (NSString *)hexString;
- (NSData*)dataWithHexString:(NSString*)hexString;
@end
