#import "ModService.h"
#import "SSZipArchive.h"
#import "SSZipCommon.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ModService ()
@end

@implementation ModService

- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化逻辑
    }
    return self;
}

- (void)analyzeJarFile:(NSString *)jarPath completion:(void(^)(NSArray *modEntries, NSError *error))completion {
    NSMutableArray *resultEntries = [NSMutableArray array];
    NSString *tempUnzipDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ModServiceTemp"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 清理旧临时目录
    if ([fm fileExistsAtPath:tempUnzipDir]) {
        [fm removeItemAtPath:tempUnzipDir error:nil];
    }
    [fm createDirectoryAtPath:tempUnzipDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // 使用 SSZipArchive 解压并枚举条目
    [SSZipArchive unzipFileAtPath:jarPath
                      toDestination:tempUnzipDir
                    progressHandler:^(NSString *entryPath, unz_file_info zipInfo, long entryNumber, long total) {
        // 过滤系统隐藏文件（如 __MACOSX 目录）
        if ([entryPath hasPrefix:@"__MACOSX/"]) return;
        
        // 构建条目信息模型
        NSDictionary *entryInfo = @{
            @"path": entryPath,
            @"size": @(zipInfo.uncompressed_size),
            @"isDirectory": @(zipInfo.flag & 0x10 ? YES : NO) // 0x10 为目录标志位
        };
        [resultEntries addObject:entryInfo];
        
        // 如需读取文件内容（替代 dataForEntryAtPath）
        if (!(zipInfo.flag & 0x10)) { // 非目录文件
            NSString *tempFilePath = [tempUnzipDir stringByAppendingPathComponent:entryPath];
            NSData *fileData = [NSData dataWithContentsOfFile:tempFilePath];
            if (fileData) {
                // 处理文件数据（例如解析清单、检测Mod类型等）
                [self processFileData:fileData forEntry:entryPath];
            }
        }
    } completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
        if (succeeded) {
            completion(resultEntries, nil);
        } else {
            completion(nil, error ?: [NSError errorWithDomain:@"ModService" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Jar解析失败"}]);
        }
        // 清理临时文件
        [fm removeItemAtPath:tempUnzipDir error:nil];
    }];
}

- (void)processFileData:(NSData *)data forEntry:(NSString *)entryPath {
    // 处理文件数据的业务逻辑
    if ([entryPath isEqualToString:@"mcmod.info"] || [entryPath isEqualToString:@"fabric.mod.json"]) {
        NSError *jsonError;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (json) {
            NSLog(@"解析Mod元数据: %@", json);
            // 提取Mod名称、版本等信息
        }
    }
}

- (void)dealloc {
    // 资源释放
}

@end
