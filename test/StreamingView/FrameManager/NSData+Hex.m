//
//  NSData+Hex.m
//  test
//
//  Created by davis.cho on 2015/9/30.
//  Copyright © 2015年 demon. All rights reserved.
//

#import "NSData+Hex.h"

@implementation NSData (Hex)

- (NSString *)hexString
{
    NSUInteger bytesCount = self.length;
    
    if (bytesCount)
    {
        static char const *kHexChars = "0123456789ABCDEFw";
        const unsigned char *dataBuffer = self.bytes;
        char *chars = malloc(sizeof(char) * (bytesCount * 2 + 1));
        char *s = chars;
        
        for (unsigned i = 0; i < bytesCount; ++i)
        {
            *s++ = kHexChars[((*dataBuffer & 0xF0) >> 4)];
            *s++ = kHexChars[(*dataBuffer & 0x0F)];
            dataBuffer++;
        }
        
        *s = '\0';
        
        NSString *hexString = [NSString stringWithUTF8String:chars];
        free(chars);
        return hexString;
    }
    
	return @"";
}

- (NSData*)dataWithHexString:(NSString*)hexString {
    NSMutableData *data= [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i = 0; i < ([hexString length] / 2); i++) {
        byte_chars[0] = [hexString characterAtIndex:i*2];
        byte_chars[1] = [hexString characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
    }
    return data;
}

@end
