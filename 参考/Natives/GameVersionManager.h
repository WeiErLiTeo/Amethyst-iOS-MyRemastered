//
//  GameVersionManager.h
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GameVersionManager : NSObject

+ (instancetype)sharedManager;

- (NSString *)getCurrentGameVersion;

@end

NS_ASSUME_NONNULL_END