//
//  GameVersionManager.m
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import "GameVersionManager.h"
#import "PLProfiles.h"

@implementation GameVersionManager

+ (instancetype)sharedManager {
    static GameVersionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GameVersionManager alloc] init];
    });
    return sharedInstance;
}

- (NSString *)getCurrentGameVersion {
    // 获取当前选中的配置文件
    NSDictionary *selectedProfile = [PLProfiles current].selectedProfile;
    
    // 从配置文件中获取lastVersionId
    NSString *lastVersionId = selectedProfile[@"lastVersionId"];
    
    if (!lastVersionId || lastVersionId.length == 0) {
        // 如果没有找到lastVersionId，返回默认版本
        return @"1.19.2"; // 默认版本，可以根据需要修改
    }
    
    // 从lastVersionId中提取游戏版本
    NSString *gameVersion = [self extractGameVersionFromVersionId:lastVersionId];
    
    if (!gameVersion || gameVersion.length == 0) {
        // 如果无法提取游戏版本，返回默认版本
        return @"1.19.2"; // 默认版本，可以根据需要修改
    }
    
    return gameVersion;
}

- (NSString *)extractGameVersionFromVersionId:(NSString *)versionId {
    if (!versionId || versionId.length == 0) {
        return nil;
    }
    
    // 处理不同格式的versionId
    // 例如: "1.19.2-forge-43.2.0" -> "1.19.2"
    // 例如: "fabric-loader-0.14.10-1.19.2" -> "1.19.2"
    // 例如: "1.19.2" -> "1.19.2"
    
    // 尝试直接匹配版本号格式 (例如 1.19.2, 1.18.1, etc.)
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+\\.\\d+(\\.\\d+)?" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:versionId options:0 range:NSMakeRange(0, versionId.length)];
    
    if (match) {
        NSRange range = [match rangeAtIndex:0];
        return [versionId substringWithRange:range];
    }
    
    // 如果正则表达式匹配失败，尝试其他方法
    // 检查是否包含"fabric-loader"或"forge"
    if ([versionId containsString:@"fabric-loader"]) {
        // 对于fabric格式，版本号通常在最后
        NSArray *components = [versionId componentsSeparatedByString:@"-"];
        for (NSString *component in [components reverseObjectEnumerator]) {
            if ([component containsString:@"."]) {
                return component;
            }
        }
    } else if ([versionId containsString:@"forge"]) {
        // 对于forge格式，版本号通常在开头
        NSArray *components = [versionId componentsSeparatedByString:@"-"];
        for (NSString *component in components) {
            if ([component containsString:@"."]) {
                return component;
            }
        }
    }
    
    // 如果以上方法都失败，直接返回versionId
    return versionId;
}

@end