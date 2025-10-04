//
//  ModItem.h
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ModItem : NSObject

// File properties
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *basename;
@property (nonatomic, assign) BOOL disabled;

// Metadata (loaded async)
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *modDescription;
@property (nonatomic, copy, nullable) NSString *version;
@property (nonatomic, copy, nullable) NSString *fileSHA1;
@property (nonatomic, copy, nullable) NSString *homepage;
@property (nonatomic, copy, nullable) NSString *sources;
@property (nonatomic, copy, nullable) NSString *iconURL;

// Loader flags (loaded async)
@property (nonatomic, assign) BOOL isFabric;
@property (nonatomic, assign) BOOL isForge;
@property (nonatomic, assign) BOOL isNeoForge;

// Update check properties
@property (nonatomic, assign) BOOL updateChecked;
@property (nonatomic, assign) BOOL updateAvailable;
@property (nonatomic, strong, nullable) NSDictionary *latestVersionInfo;

// Loading status
@property (nonatomic, assign) BOOL metadataLoaded;

// Designated initializer
- (instancetype)initWithFilePath:(NSString *)filePath;

// Refresh disabled flag from current file name
- (void)refreshDisabledFlag;

// Reset update check status
- (void)resetUpdateCheckStatus;

@end

NS_ASSUME_NONNULL_END