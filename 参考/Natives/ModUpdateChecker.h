//
//  ModUpdateChecker.h
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import <Foundation/Foundation.h>
#import "ModItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModUpdateChecker : NSObject

+ (instancetype)sharedChecker;

- (void)checkUpdatesForMod:(ModItem *)mod withGameVersion:(NSString *)gameVersion completion:(void (^)(NSDictionary * _Nullable updateInfo, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END