//
//  ModBackupManager.h
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import <Foundation/Foundation.h>
#import "ModItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModBackupManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)backupMod:(ModItem *)mod error:(NSError **)error;
- (NSArray<NSString *> *)getBackupFilesForMod:(ModItem *)mod;
- (BOOL)restoreModFromBackup:(NSString *)backupPath mod:(ModItem *)mod error:(NSError **)error;
- (NSString *)getBackupPathForMod:(ModItem *)mod;

@end

NS_ASSUME_NONNULL_END