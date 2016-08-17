//
//  main.m
//  LocalizableStringsAssistant
//
//  Created by BobZhang on 16/7/26.
//  Copyright © 2016年 ZhangBaoGuo. All rights reserved.
//

// 目的：把本地化字符串中 "key" = "value"；行的 value 替换成 comment

//  正常格式
//  /* comment */
//  "key" = "value"；

//  非正常格式之一 ： 一个key，多个说明
//  /* comment1
//     comment2
//     comment3 */
//  "key" = "value"；

//  非正常格式之二 ： 没有说明
//  /* No comment provided by engineer. */
//  "key" = "value"；

// 区分以上格式分别处理

#define NoCommentTip  @"No comment provided by engineer."

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *pathString = [[NSString alloc] initWithCString:argv[1] encoding:NSUTF8StringEncoding];
        
        if (!pathString){
            NSLog(@"Please give a Localizable.strings file full path as an argument.");
            return 0;
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:pathString isDirectory:NO]){
            NSLog(@"The Localizable.strings file did not exist.");
            return 0;
        }
        
        NSLog(@"Localizable.strings :\n%@\nChanging value in key = vlaue pair to comment...\nPlease wait...",pathString);
        
        NSError *error;
        
        /*
        //NSString *localFilePath = [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings"];
        //NSString *localFilePath = @"~/Documents/Localizable.strings";
        NSString *localFilePath = @"/Users/BobZhang/Documents/Localizable.strings";
         

        NSLog(@"%@",localFilePath);
         
         */
        
        NSString *localFileString = [NSString stringWithContentsOfFile:pathString encoding:NSUTF16StringEncoding error:&error];
        
        if (!localFileString)
        {
            NSLog(@"Could not read file: %@", error.localizedFailureReason);
            return 0;
        }
        
        // 将本地化文件拆分成行
        NSArray <NSString *> *lines = [localFileString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        // 存储结果
        NSMutableString *resultString = [NSMutableString new];
        // 存储工程师添加的说明，以下简称comment
        NSString *comment = @"";
        
        // 标识comment是否结束
        BOOL commentHasReachEnd = YES;
        
        // 标识是否 没有comment
        BOOL noComment = NO;
        
        for (NSString *aLine in lines) {
            
            // 只包含空格的行直接跳过
            if ([[aLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) continue;
            
            // 只包含@"/* "，说明该行包含一条comment，但comment没有结束
            if ([aLine rangeOfString:@"/* "].length && ![aLine rangeOfString:@" */"].length){
                comment = [aLine stringByReplacingOccurrencesOfString:@"/* " withString:@""];
                commentHasReachEnd = NO;
                continue;
            }
            
            // 只包含@" */"，说明该行包含一条重复的comment，并且该comment在本行结束，重复的comment以/分隔
            if (![aLine rangeOfString:@"/* "].length && [aLine rangeOfString:@" */"].length){
                NSString *commentToAdd = [aLine stringByReplacingOccurrencesOfString:@" */" withString:@""];
                commentToAdd = [commentToAdd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                comment = [NSString stringWithFormat:@"%@/%@",comment,commentToAdd];
                commentHasReachEnd = YES;
                continue;
            }
            
            // comment没有结束，说明该行包含一条重复的comment，直接添加（没有结束的原因是一个key有2个或以上的comment），重复的comment以/分隔
            if (!commentHasReachEnd) {
                NSString *commentToAdd = [aLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                comment = [NSString stringWithFormat:@"%@/%@",comment,commentToAdd];
                continue;
            }

            // 包含@"/* "和@" */"，说明
            if ([aLine rangeOfString:@"/* "].length && [aLine rangeOfString:@" */"].length) {
                comment = [aLine stringByReplacingOccurrencesOfString:@"/* " withString:@""];
                comment = [comment stringByReplacingOccurrencesOfString:@" */" withString:@""];
                
                // 这条本地化字符串没有comment，记录标识，单独处理
                if ([comment isEqualToString:NoCommentTip]) noComment = YES;
                // 否则，这是一条正常的本地化字符串——有comment且comment唯一，最好的状态
                
                continue;
            }
            
            // "key" = "value" 行
            NSRange equalCharacterRange = [aLine rangeOfString:@"\" = \""];
            if (equalCharacterRange.length){
                // 把 " = " 之后的部分截除，保留下 "key" = "
                NSString *keyValueLine = [aLine substringToIndex:equalCharacterRange.location + equalCharacterRange.length];
                
                //keyValueLine = [keyValueLine stringByReplacingOccurrencesOfString:@"\";" withString:@""];
                
                if (noComment){
                    // 没有comment
                    keyValueLine = aLine;
                    
                    // 重设noComment
                    noComment = NO;
                }else{
                    // 有comment，把value替换为comment
                    // keyValueLine 添加 comment"; 这样keyValueLine就成了 "key" = "comment";
                    keyValueLine = [NSString stringWithFormat:@"%@%@\";",keyValueLine,comment];
                }
                
                // 按原格式添加（一行/* comment */，一行"key" = "value")
                [resultString appendString:[NSString stringWithFormat:@"/* %@ */\n%@\n",comment,keyValueLine]];
                // comment置空
                comment = @"";
            }
        }
        
        // 存储结果
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyy-MM-dd_hh-mm-ss"];
        NSString *originalFileName = [pathString lastPathComponent];
        NSString *directoryPath = [pathString stringByDeletingLastPathComponent];
        NSString *resultFilePath = [NSString stringWithFormat:@"%@/ReplaceValueWithComment_%@_%@",directoryPath,[dateFormatter stringFromDate:[NSDate date]],originalFileName];
        
        BOOL succeeded = [resultString writeToFile:resultFilePath atomically:YES encoding:NSUTF16StringEncoding error:&error];
        if (succeeded) {
            NSLog(@"Successfully save to file : %@",resultFilePath);
            return 1;
        }else{
            NSLog(@"WriteToFile Failed : %@", error.localizedFailureReason);
            return 0;
        }

    }
    return 0;
}
