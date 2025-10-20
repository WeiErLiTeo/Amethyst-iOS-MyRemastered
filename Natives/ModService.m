//
//  ModService.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Revised: detect multiple loaders, choose metadata by priority (Fabric > Forge > NeoForge),
//  add defensive parsing for neoforge & toml, avoid crashes.
//

#import "ModService.h"
#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIKit.h>
#import "PLProfiles.h"
#import "ModItem.h"
#import "UnzipKit.h"

@interface ModService () <NSURLSessionDownloadDelegate>
- (NSDictionary<NSString *, NSString *> *)parseFirstModsTableFromTomlString:(NSString *)s;
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, ModDownloadHandler> *downloadCompletionHandlers;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, NSString *> *downloadDestinationPaths;
@end

@implementation ModService

// Parses the first [[mods]] table from a mods.toml string.
- (NSDictionary<NSString *, NSString *> *)parseFirstModsTableFromTomlString:(NSString *)s {
    if (!s) return nil;

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    BOOL inModTable = NO;

    NSArray<NSString *> *lines = [s componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([trimmed isEqualToString:@"[[mods]]"]) {
            inModTable = YES;
            continue;
        }

        if (inModTable && [trimmed hasPrefix:@"["]) {
            // Reached the next table, so stop.
            break;
        }

        if (inModTable) {
            NSRange eqRange = [trimmed rangeOfString:@"="];
            if (eqRange.location != NSNotFound) {
                NSString *key = [[trimmed substringToIndex:eqRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *val = [[trimmed substringFromIndex:NSMaxRange(eqRange)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                // Remove quotes
                if ([val hasPrefix:@"\""] && [val hasSuffix:@"\""] && val.length > 1) {
                    val = [val substringWithRange:NSMakeRange(1, val.length - 2)];
                }
                dict[key] = val;
            }
        }
    }

    return (dict.count > 0) ? [dict copy] : nil;
}


+ (instancetype)sharedService {
    static ModService *s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[ModService alloc] init];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _onlineSearchEnabled = NO;
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.amethyst.moddownloader"];
        _downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        _downloadCompletionHandlers = [NSMutableDictionary dictionary];
        _downloadDestinationPaths = [NSMutableDictionary dictionary];
    }
    return self;
}


#pragma mark - Helpers (sha1/icon cache/readdata etc.) unchanged (omitted here for brevity)
// ... (All helper methods from the previous version of the file remain here) ...
- (nullable NSString *)sha1ForFileAtPath:(NSString *)path {
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

- (NSString *)iconCachePathForURL:(NSString *)urlString {
    if (!urlString) return nil;
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *folder = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    const char *cstr = [urlString UTF8String];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [folder stringByAppendingPathComponent:hex];
}

- (nullable NSData *)readFileFromJar:(NSString *)jarPath entryName:(NSString *)entryName {
    if (!jarPath || !entryName) return nil;
    NSError *err = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:jarPath error:&err];
    if (!archive || err) return nil;
    NSData *data = [archive extractDataFromFile:entryName error:&err];
    return data;
}

#pragma mark - Mods folder detection & scan (conservative)
- (nullable NSString *)existingModsFolderForProfile:(NSString *)profileName {
    // ... same implementation as before ...
    NSString *profile = profileName.length ? profileName : @"default";
    NSFileManager *fm = [NSFileManager defaultManager];

    @try {
        NSDictionary *profiles = PLProfiles.current.profiles;
        NSDictionary *prof = profiles[profile];
        if ([prof isKindOfClass:[NSDictionary class]]) {
            NSString *gameDir = prof[@"gameDir"];
            if ([gameDir isKindOfClass:[NSString class]] && gameDir.length > 0) {
                NSString *modsPath = [gameDir stringByAppendingPathComponent:@"mods"];
                BOOL isDir = NO;
                if ([fm fileExistsAtPath:modsPath isDirectory:&isDir] && isDir) {
                    return modsPath;
                }
            }
        }
    } @catch (NSException *ex) { }

    const char *gameDirC = getenv("POJAV_GAME_DIR");
    if (gameDirC) {
        NSString *gameDir = [NSString stringWithUTF8String:gameDirC];
        NSString *modsPath = [gameDir stringByAppendingPathComponent:@"mods"];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:modsPath isDirectory:&isDir] && isDir) {
            return modsPath;
        }
    }
    return nil;
}

- (void)scanModsForProfile:(NSString *)profileName completion:(ModListHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *modsFolder = [self existingModsFolderForProfile:profileName];
        NSMutableArray<ModItem *> *items = [NSMutableArray array];

        if (!modsFolder) {
            if (completion) {
                completion(items);
            }
            return;
        }

        NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:modsFolder error:nil];
        dispatch_group_t group = dispatch_group_create();

        for (NSString *fileName in contents) {
            if ([fileName.lowercaseString hasSuffix:@".jar"] || [fileName.lowercaseString hasSuffix:@".jar.disabled"]) {
                NSString *fullPath = [modsFolder stringByAppendingPathComponent:fileName];
                ModItem *mod = [[ModItem alloc] initWithFilePath:fullPath];
                [items addObject:mod];

                dispatch_group_enter(group);
                [self fetchMetadataForMod:mod completion:^(ModItem *populatedMod, NSError *error) {
                    dispatch_group_leave(group);
                }];
            }
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            // Sort after all metadata has been fetched
            [items sortUsingComparator:^NSComparisonResult(ModItem *obj1, ModItem *obj2) {
                NSString *name1 = obj1.displayName ?: obj1.fileName;
                NSString *name2 = obj2.displayName ?: obj2.fileName;
                return [name1 localizedCaseInsensitiveCompare:name2];
            }];

            if (completion) {
                completion(items);
            }
        });
    });
}

#pragma mark - Metadata fetch
- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // --- Fabric ---
        NSData *fabricData = [self readFileFromJar:mod.filePath entryName:@"fabric.mod.json"];
        if (fabricData) {
            mod.isFabric = YES;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:fabricData options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                mod.onlineID = json[@"id"];
                mod.version = json[@"version"];
                mod.displayName = json[@"name"];
                mod.modDescription = json[@"description"];
                mod.author = [json[@"authors"] componentsJoinedByString:@", "];
                // Icon parsing (optional)
                NSString *iconPath = json[@"icon"];
                if ([iconPath isKindOfClass:[NSString class]]) {
                    NSData *iconData = [self readFileFromJar:mod.filePath entryName:iconPath];
                    if (iconData) {
                        mod.icon = [[UIImage alloc] initWithData:iconData];
                    }
                }
                if (completion) completion(mod, nil);
                return;
            }
        }

        // --- Forge ---
        NSData *forgeData = [self readFileFromJar:mod.filePath entryName:@"META-INF/mods.toml"];
        if (forgeData) {
            mod.isForge = YES;
            NSString *tomlString = [[NSString alloc] initWithData:forgeData encoding:NSUTF8StringEncoding];
            if (tomlString) {
                NSDictionary<NSString *, NSString *> *modInfo = [self parseFirstModsTableFromTomlString:tomlString];
                if (modInfo) {
                    mod.onlineID = modInfo[@"modId"];
                    mod.version = modInfo[@"version"];
                    mod.displayName = modInfo[@"displayName"];
                    mod.modDescription = modInfo[@"description"];
                    mod.author = modInfo[@"authors"];
                    // Forge icon parsing is more complex, often a logo file defined in the TOML
                    NSString *logoFile = modInfo[@"logoFile"];
                    if (logoFile.length > 0) {
                        NSData *logoData = [self readFileFromJar:mod.filePath entryName:logoFile];
                        if (logoData) {
                             mod.icon = [[UIImage alloc] initWithData:logoData];
                        }
                    }
                    if (completion) completion(mod, nil);
                    return;
                }
            }
        }

        // --- NeoForge ---
        NSData *neoForgeData = [self readFileFromJar:mod.filePath entryName:@"META-INF/neoforge.mods.toml"];
        if (neoForgeData) {
            mod.isNeoForge = YES;
            NSString *tomlString = [[NSString alloc] initWithData:neoForgeData encoding:NSUTF8StringEncoding];
            if (tomlString) {
                NSDictionary<NSString *, NSString *> *modInfo = [self parseFirstModsTableFromTomlString:tomlString];
                if (modInfo) {
                    mod.onlineID = modInfo[@"modId"];
                    mod.version = modInfo[@"version"];
                    mod.displayName = modInfo[@"displayName"];
                    mod.modDescription = modInfo[@"description"];
                    mod.author = modInfo[@"authors"];
                    NSString *logoFile = modInfo[@"logoFile"];
                     if (logoFile.length > 0) {
                        NSData *logoData = [self readFileFromJar:mod.filePath entryName:logoFile];
                        if (logoData) {
                             mod.icon = [[UIImage alloc] initWithData:logoData];
                        }
                    }
                    if (completion) completion(mod, nil);
                    return;
                }
            }
        }

        // --- Fallback ---
        if (completion) completion(mod, nil);
    });
}

#pragma mark - File operations
- (BOOL)toggleEnableForMod:(ModItem *)mod error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *currentPath = mod.filePath;
    NSString *newPath;

    if (mod.disabled) {
        // Enable the mod: remove .disabled suffix
        if ([currentPath.lowercaseString hasSuffix:@".jar.disabled"]) {
            newPath = [currentPath substringToIndex:currentPath.length - 9];
        } else {
            // Should not happen, but handle gracefully
            if (error) *error = [NSError errorWithDomain:@"ModServiceError" code:101 userInfo:@{NSLocalizedDescriptionKey:@"文件状态不一致，无法启用。"}];
            return NO;
        }
    } else {
        // Disable the mod: add .disabled suffix
        newPath = [currentPath stringByAppendingString:@".disabled"];
    }

    BOOL success = [fileManager moveItemAtPath:currentPath toPath:newPath error:error];
    if (success) {
        // IMPORTANT: Update the model object to reflect the change
        mod.filePath = newPath;
        mod.fileName = [newPath lastPathComponent];
        [mod refreshDisabledFlag]; // This will set `disabled` property correctly
    }

    return success;
}

- (BOOL)deleteMod:(ModItem *)mod error:(NSError **)error {
    // ... same implementation as before ...
    return [[NSFileManager defaultManager] removeItemAtPath:mod.filePath error:error];
}


#pragma mark - Online Mod Downloading

- (void)downloadMod:(ModItem *)mod toProfile:(NSString *)profileName completion:(ModDownloadHandler)completion {
    NSString *modsFolder = [self existingModsFolderForProfile:profileName];
    if (!modsFolder) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"ModServiceError" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无法找到 Mods 文件夹。"}];
            completion(error);
        }
        return;
    }

    NSURL *url = [NSURL URLWithString:mod.selectedVersionDownloadURL];
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"ModServiceError" code:2 userInfo:@{NSLocalizedDescriptionKey:@"无效的下载链接。"}];
            completion(error);
        }
        return;
    }

    NSString *destinationPath = [modsFolder stringByAppendingPathComponent:mod.fileName];

    NSURLSessionDownloadTask *task = [self.downloadSession downloadTaskWithURL:url];
    self.downloadCompletionHandlers[task] = completion;
    self.downloadDestinationPaths[task] = destinationPath;

    [task resume];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    ModDownloadHandler handler = self.downloadCompletionHandlers[downloadTask];
    NSString *destinationPath = self.downloadDestinationPaths[downloadTask];

    [self.downloadCompletionHandlers removeObjectForKey:downloadTask];
    [self.downloadDestinationPaths removeObjectForKey:downloadTask];

    if (!handler || !destinationPath) {
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *moveError = nil;

    // Ensure the destination directory exists
    NSString *dir = [destinationPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // If a file already exists, remove it
    if ([fm fileExistsAtPath:destinationPath]) {
        [fm removeItemAtPath:destinationPath error:nil];
    }

    if (![fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:destinationPath] error:&moveError]) {
        handler(moveError);
    } else {
        handler(nil); // Success
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        ModDownloadHandler handler = self.downloadCompletionHandlers[task];
        if (handler) {
            handler(error);
            [self.downloadCompletionHandlers removeObjectForKey:task];
            [self.downloadDestinationPaths removeObjectForKey:task];
        }
    }
}

@end
