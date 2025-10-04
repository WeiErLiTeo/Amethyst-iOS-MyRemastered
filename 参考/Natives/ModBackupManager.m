//
//  ModBackupManager.m
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import "ModBackupManager.h"

@implementation ModBackupManager

+ (instancetype)sharedManager {
    static ModBackupManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ModBackupManager alloc] init];
    });
    return sharedInstance;
}

- (BOOL)backupMod:(ModItem *)mod error:(NSError **)error {
    NSString *filePath = mod.filePath;
    NSString *fileName = mod.fileName;
    NSString *backupFileName = [fileName stringByAppendingPathExtension:@"old"];
    NSString *backupPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:backupFileName];
    
    // 如果已经是备份文件，直接返回
    if ([fileName hasSuffix:@".old"]) {
        if (error) *error = [NSError errorWithDomain:@"ModBackupManagerErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"文件已经是备份文件"}];
        return NO;
    }
    
    // 检查备份文件是否已存在
    if ([[NSFileManager defaultManager] fileExistsAtPath:backupPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:backupPath error:error]) {
            return NO;
        }
    }
    
    // 重命名文件为备份文件
    if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:backupPath error:error]) {
        return NO;
    }
    
    return YES;
}

- (NSArray<NSString *> *)getBackupFilesForMod:(ModItem *)mod {
    NSString *modsDirectory = [mod.filePath stringByDeletingLastPathComponent];
    NSString *baseFileName = mod.basename;
    
    // 获取目录中的所有文件
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:modsDirectory error:nil];
    
    // 筛选出该Mod的备份文件
    NSMutableArray *backupFiles = [NSMutableArray array];
    for (NSString *file in files) {
        if ([file hasPrefix:baseFileName] && [file hasSuffix:@".old"]) {
            NSString *fullPath = [modsDirectory stringByAppendingPathComponent:file];
            [backupFiles addObject:fullPath];
        }
    }
    
    return [backupFiles copy];
}

- (BOOL)restoreModFromBackup:(NSString *)backupPath mod:(ModItem *)mod error:(NSError **)error {
    // 检查备份文件是否存在
    if (![[NSFileManager defaultManager] fileExistsAtPath:backupPath]) {
        if (error) *error = [NSError errorWithDomain:@"ModBackupManagerErrorDomain" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"备份文件不存在"}];
        return NO;
    }
    
    // 获取原始文件路径
    NSString *originalFileName = mod.basename;
    NSString *originalPath = [[backupPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:originalFileName];
    
    // 检查原始文件是否已存在
    if ([[NSFileManager defaultManager] fileExistsAtPath:originalPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:originalPath error:error]) {
            return NO;
        }
    }
    
    // 重命名备份文件为原始文件
    if (![[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:originalPath error:error]) {
        return NO;
    }
    
    return YES;
}

- (NSString *)getBackupPathForMod:(ModItem *)mod {
    NSString *filePath = mod.filePath;
    NSString *fileName = mod.fileName;
    NSString *backupFileName = [fileName stringByAppendingPathExtension:@"old"];
    return [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:backupFileName];
}

@end