//
//  ModUpdateChecker.m
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import "ModUpdateChecker.h"
#import <CommonCrypto/CommonCrypto.h>
#import "ModService.h"

@implementation ModUpdateChecker

+ (instancetype)sharedChecker {
    static ModUpdateChecker *s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [ModUpdateChecker new];
    });
    return s;
}

- (void)checkUpdatesForMod:(ModItem *)mod withGameVersion:(NSString *)gameVersion completion:(void (^)(NSDictionary * _Nullable updateInfo, NSError * _Nullable error))completion {
    // 获取Mod的SHA1哈希值
    NSString *sha1 = [self sha1ForFileAtPath:mod.filePath];
    if (!sha1) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ModUpdateCheckerErrorDomain" code:-1002 userInfo:@{NSLocalizedDescriptionKey: @"无法计算文件哈希值"}]);
        return;
    }
    
    // 检查游戏版本是否有效
    if (!gameVersion || gameVersion.length == 0) {
        NSLog(@"无效的游戏版本，使用默认版本");
        gameVersion = @"1.19.2";
    }
    
    NSLog(@"开始检查Mod更新: %@, SHA1: %@, 游戏版本: %@", mod.displayName ?: mod.fileName, sha1, gameVersion);
    
    // 直接尝试检查更新，而不是预先检查网络连接
    // 这样可以避免网络检查本身的问题导致的误判
    [self checkModrinthForUpdate:mod withSHA1:sha1 andGameVersion:gameVersion completion:^(NSDictionary * _Nullable updateInfo, NSError * _Nullable error) {
        // 如果Modrinth检查失败且是网络相关错误，则尝试CurseForge
        if (error && (error.code == -1001 || error.code == -1009 || error.code == -1004)) {
            // 网络错误，记录日志但不阻塞
            NSLog(@"Modrinth更新检查网络错误: %@", error.localizedDescription);
            if (completion) completion(nil, nil);  // 不阻塞，直接返回无更新
            return;
        }
        
        if (error) {
            // 其他错误，记录日志
            NSLog(@"Modrinth更新检查错误: %@", error.localizedDescription);
        }
        
        if (updateInfo) {
            NSLog(@"在Modrinth找到更新: %@", updateInfo[@"name"] ?: updateInfo[@"title"] ?: @"未知");
            if (completion) completion(updateInfo, nil);
        } else {
            NSLog(@"在Modrinth未找到更新，尝试CurseForge");
            // 如果Modrinth没有找到更新，尝试使用CurseForge API检查更新
            [self checkCurseForgeForUpdate:mod withSHA1:sha1 andGameVersion:gameVersion completion:^(NSDictionary * _Nullable cfUpdateInfo, NSError * _Nullable cfError) {
                // 同样处理CurseForge的网络错误
                if (cfError && (cfError.code == -1001 || cfError.code == -1009 || cfError.code == -1004)) {
                    NSLog(@"CurseForge更新检查网络错误: %@", cfError.localizedDescription);
                    if (completion) completion(nil, nil);  // 不阻塞，直接返回无更新
                    return;
                }
                
                if (cfError) {
                    // 其他错误，记录日志
                    NSLog(@"CurseForge更新检查错误: %@", cfError.localizedDescription);
                }
                
                if (cfUpdateInfo) {
                    NSLog(@"在CurseForge找到更新");
                } else {
                    NSLog(@"在CurseForge未找到更新");
                }
                
                if (completion) completion(cfUpdateInfo, cfError);
            }];
        }
    }];
}

- (NSString *)sha1ForFileAtPath:(NSString *)path {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) return nil;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(d.bytes, (CC_LONG)d.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [hex copy];
}

- (void)checkModrinthForUpdate:(ModItem *)mod withSHA1:(NSString *)sha1 andGameVersion:(NSString *)gameVersion completion:(void (^)(NSDictionary * _Nullable updateInfo, NSError * _Nullable error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/version_file/%@", sha1];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, [NSError errorWithDomain:@"ModUpdateCheckerErrorDomain" code:-1003 userInfo:@{NSLocalizedDescriptionKey: @"服务器返回空数据"}]);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        // 解析Modrinth响应
        if (json[@"id"] && [json[@"files"] isKindOfClass:[NSArray class]] && [(NSArray *)json[@"files"] count] > 0) {
            // 获取项目ID以获取项目信息
            NSString *projectID = json[@"project_id"];
            if (projectID) {
                [self fetchModrinthProjectInfo:projectID completion:^(NSDictionary * _Nullable projectInfo, NSError * _Nullable projectError) {
                    if (projectInfo) {
                        // 检查是否有更新的版本
                        [self fetchModrinthProjectVersions:projectID withGameVersion:gameVersion completion:^(NSArray * _Nullable versions, NSError * _Nullable versionsError) {
                            if (versions && versions.count > 0) {
                                // 查找比当前版本更新的版本
                                NSDictionary *latestVersion = [self findLatestVersion:versions currentVersion:json];
                                if (latestVersion && ![latestVersion[@"id"] isEqualToString:json[@"id"]]) {
                                    NSMutableDictionary *updateInfo = [NSMutableDictionary dictionaryWithDictionary:projectInfo];
                                    updateInfo[@"latestVersion"] = latestVersion;
                                    updateInfo[@"updateAvailable"] = @YES;
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if (completion) completion(updateInfo, nil);
                                    });
                                    return;
                                }
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (completion) completion(nil, nil);
                            });
                        }];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completion) completion(nil, projectError);
                        });
                    }
                }];
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, nil);
        });
    }];
    
    [task resume];
}

- (void)fetchModrinthProjectInfo:(NSString *)projectID completion:(void (^)(NSDictionary * _Nullable projectInfo, NSError * _Nullable error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", projectID];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, [NSError errorWithDomain:@"ModUpdateCheckerErrorDomain" code:-1003 userInfo:@{NSLocalizedDescriptionKey: @"服务器返回空数据"}]);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(json, nil);
        });
    }];
    
    [task resume];
}

- (void)fetchModrinthProjectVersions:(NSString *)projectID withGameVersion:(NSString *)gameVersion completion:(void (^)(NSArray * _Nullable versions, NSError * _Nullable error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version", projectID];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, [NSError errorWithDomain:@"ModUpdateCheckerErrorDomain" code:-1003 userInfo:@{NSLocalizedDescriptionKey: @"服务器返回空数据"}]);
            });
            return;
        }
        
        NSError *jsonError;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        // 过滤版本
        NSMutableArray *filteredVersions = [NSMutableArray array];
        for (NSDictionary *version in json) {
            if ([version[@"game_versions"] isKindOfClass:[NSArray class]]) {
                NSArray *gameVersions = version[@"game_versions"];
                if ([gameVersions containsObject:gameVersion]) {
                    [filteredVersions addObject:version];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(filteredVersions, nil);
        });
    }];
    
    [task resume];
}

- (NSDictionary *)findLatestVersion:(NSArray *)versions currentVersion:(NSDictionary *)currentVersion {
    if (versions.count == 0) {
        return nil;
    }
    
    // 获取当前版本号
    NSString *currentVersionNumber = currentVersion[@"version_number"];
    if (!currentVersionNumber) {
        // 如果没有version_number，尝试使用name
        currentVersionNumber = currentVersion[@"name"];
    }
    
    // 初始化最新版本为nil
    NSDictionary *latestVersion = nil;
    NSString *latestVersionNumber = nil;
    
    // 遍历所有版本，找到比当前版本更新的最新版本
    for (NSDictionary *version in versions) {
        NSString *versionNumber = version[@"version_number"];
        if (!versionNumber) {
            versionNumber = version[@"name"];
        }
        
        // 如果这是当前版本，跳过
        if ([versionNumber isEqualToString:currentVersionNumber]) {
            continue;
        }
        
        // 如果还没有找到最新版本，或者找到的版本比当前最新版本更新
        if (!latestVersionNumber || [self isVersion:versionNumber greaterThanVersion:latestVersionNumber]) {
            latestVersion = version;
            latestVersionNumber = versionNumber;
        }
    }
    
    return latestVersion;
}

- (BOOL)isVersion:(NSString *)version1 greaterThanVersion:(NSString *)version2 {
    if (!version1 || !version2) {
        return NO;
    }
    
    // 移除版本号前的非数字字符（如v）
    version1 = [version1 stringByReplacingOccurrencesOfString:@"^[^0-9]*" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, version1.length)];
    version2 = [version2 stringByReplacingOccurrencesOfString:@"^[^0-9]*" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, version2.length)];
    
    // 处理空字符串情况
    if (version1.length == 0 || version2.length == 0) {
        return NO;
    }
    
    // 按点分割版本号
    NSArray *components1 = [version1 componentsSeparatedByString:@"."];
    NSArray *components2 = [version2 componentsSeparatedByString:@"."];
    
    // 比较每个组件
    NSUInteger maxComponents = MAX(components1.count, components2.count);
    for (NSUInteger i = 0; i < maxComponents; i++) {
        NSInteger num1 = 0;
        NSInteger num2 = 0;
        
        if (i < components1.count) {
            num1 = [components1[i] integerValue];
        }
        
        if (i < components2.count) {
            num2 = [components2[i] integerValue];
        }
        
        if (num1 > num2) {
            return YES;
        } else if (num1 < num2) {
            return NO;
        }
        // 如果相等，继续比较下一个组件
    }
    
    // 版本号相等
    return NO;
}

- (void)checkCurseForgeForUpdate:(ModItem *)mod withSHA1:(NSString *)sha1 andGameVersion:(NSString *)gameVersion completion:(void (^)(NSDictionary * _Nullable updateInfo, NSError * _Nullable error))completion {
    // CurseForge API需要API密钥，这里提供一个简化实现
    // 在实际应用中，您需要获取并使用有效的API密钥
    
    // 由于CurseForge API的复杂性和需要API密钥，这里只是提供一个框架
    // 您可以根据需要实现完整的CurseForge更新检查逻辑
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(nil, nil); // 暂时不支持CurseForge更新检查
    });
}

- (void)checkNetworkAvailabilityWithCompletion:(void (^)(BOOL isAvailable))completion {
    // 简化网络检查，直接返回YES，让实际的API调用来判断网络状态
    if (completion) completion(YES);
}

- (BOOL)isNetworkAvailable {
    // 简化实现，总是返回YES
    return YES;
}

@end