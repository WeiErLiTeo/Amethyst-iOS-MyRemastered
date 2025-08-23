//
//  ModService.h
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import <Foundation/Foundation.h>
#import "ModItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^ModListHandler)(NSArray<ModItem *> *mods);
typedef void(^ModMetadataHandler)(ModItem *item, NSError * _Nullable error);

@interface ModService : NSObject

+ (instancetype)sharedService;

- (void)scanModsForProfile:(NSString *)profileName completion:(ModListHandler)completion;
- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion;
- (NSString *)iconCachePathForURL:(NSString *)urlString;
- (BOOL)toggleEnableForMod:(ModItem *)mod error:(NSError **)error;
- (BOOL)deleteMod:(ModItem *)mod error:(NSError **)error;

// Return an existing mods folder path for the given profile if found, otherwise nil.
- (nullable NSString *)existingModsFolderForProfile:(NSString *)profileName;

// Controls whether metadata fetching should prefer online search first (YES)
// or local jar parsing first (NO). Defaults to NO.
@property (nonatomic, assign) BOOL onlineSearchEnabled;

@end

NS_ASSUME_NONNULL_END