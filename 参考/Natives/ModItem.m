//
//  ModItem.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import "ModItem.h"

@implementation ModItem

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        _filePath = filePath.copy;
        _fileName = filePath.lastPathComponent.copy;
        _basename = [_fileName stringByDeletingPathExtension].copy;
        [self refreshDisabledFlag];
        
        // Initialize loader flags to NO
        _isFabric = NO;
        _isForge = NO;
        _isNeoForge = NO;
        
        // Initialize update check properties
        _updateChecked = NO;
        _updateAvailable = NO;
        _latestVersionInfo = nil;
        
        // Initialize loading status
        _metadataLoaded = NO;
    }
    return self;
}

- (void)refreshDisabledFlag {
    _disabled = [_fileName hasSuffix:@".disabled"];
}

- (void)resetUpdateCheckStatus {
    _updateChecked = NO;
    _updateAvailable = NO;
    _latestVersionInfo = nil;
}

@end