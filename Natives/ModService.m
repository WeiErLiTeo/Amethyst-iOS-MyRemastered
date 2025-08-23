//
//  ModService.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import "ModService.h"
#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIKit.h>
#import "PLProfiles.h"

@implementation ModService

+ (instancetype)sharedService {
    static ModService *s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [ModService new];
        s.onlineSearchEnabled = NO;
    });
    return s;
}

#pragma mark - Paths

// Return a default mods path for a profile (does NOT check existence)
- (NSString *)modsPathForProfile:(NSString *)profileName {
    NSString *profile = profileName.length ? profileName : @"default";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    return [documents stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", profile]];
}

// Return first existing mods folder candidate, otherwise nil.
- (nullable NSString *)existingModsFolderForProfile:(NSString *)profileName {
    NSString *profile = profileName.length ? profileName : @"default";
    NSFileManager *fm = NSFileManager.defaultManager;

    // If PLProfiles contains an explicit gameDir for this profile, try to resolve it first.
    @try {
        NSDictionary *profiles = PLProfiles.current.profiles;
        NSDictionary *prof = profiles[profile];
        if ([prof isKindOfClass:[NSDictionary class]]) {
            NSString *gameDir = prof[@"gameDir"];
            if ([gameDir isKindOfClass:[NSString class]] && gameDir.length > 0) {
                // If starts with "./" -> relative to POJAV_GAME_DIR
                if ([gameDir hasPrefix:@"./"]) {
                    const char *gameDirC = getenv("POJAV_GAME_DIR");
                    if (gameDirC) {
                        NSString *pojGameDir = [NSString stringWithUTF8String:gameDirC];
                        NSString *rel = [gameDir substringFromIndex:2]; // strip ./
                        NSString *cand = [pojGameDir stringByAppendingPathComponent:rel];
                        NSString *candMods = [cand stringByAppendingPathComponent:@"mods"];
                        BOOL isDir = NO;
                        if ([fm fileExistsAtPath:candMods isDirectory:&isDir] && isDir) return candMods;
                        if ([fm fileExistsAtPath:cand isDirectory:&isDir] && isDir) {
                            NSString *cand2 = [cand stringByAppendingPathComponent:@"mods"];
                            if ([fm fileExistsAtPath:cand2 isDirectory:&isDir] && isDir) return cand2;
                        }
                    }
                } else if ([gameDir hasPrefix:@"/"]) {
                    // absolute path
                    NSString *candMods = [gameDir stringByAppendingPathComponent:@"mods"];
                    BOOL isDir = NO;
                    if ([fm fileExistsAtPath:candMods isDirectory:&isDir] && isDir) return candMods;
                    if ([fm fileExistsAtPath:gameDir isDirectory:&isDir] && isDir) {
                        NSString *cand2 = [gameDir stringByAppendingPathComponent:@"mods"];
                        if ([fm fileExistsAtPath:cand2 isDirectory:&isDir] && isDir) return cand2;
                    }
                } else {
                    // treat as an instance name or relative instance folder
                    const char *pojHomeC = getenv("POJAV_HOME");
                    if (pojHomeC) {
                        NSString *pojHome = [NSString stringWithUTF8String:pojHomeC];
                        NSString *cand1 = [pojHome stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", gameDir]];
                        BOOL isDir = NO;
                        if ([fm fileExistsAtPath:cand1 isDirectory:&isDir] && isDir) return cand1;
                    }
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                    NSString *documents = paths.firstObject;
                    NSString *cand2 = [documents stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", gameDir]];
                    BOOL isDir2 = NO;
                    if ([fm fileExistsAtPath:cand2 isDirectory:&isDir2] && isDir2) return cand2;
                }
            }
        }
    } @catch (NSException *ex) {
        // ignore and proceed to general candidates
    }

    // Candidate 1: POJAV_HOME/instances/<profile>/mods
    const char *pojHomeC = getenv("POJAV_HOME");
    if (pojHomeC) {
        NSString *pojHome = [NSString stringWithUTF8String:pojHomeC];
        NSString *cand1 = [pojHome stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", profile]];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:cand1 isDirectory:&isDir] && isDir) return cand1;
    }

    // Candidate 2: Documents/instances/<profile>/mods
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    NSString *cand2 = [documents stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", profile]];
    BOOL isDir2 = NO;
    if ([fm fileExistsAtPath:cand2 isDirectory:&isDir2] && isDir2) return cand2;

    // Candidate 3: POJAV_GAME_DIR/mods (POJAV_GAME_DIR may be a symlink to the selected instance)
    const char *gameDirC = getenv("POJAV_GAME_DIR");
    if (gameDirC) {
        NSString *gameDir = [NSString stringWithUTF8String:gameDirC];
        NSString *cand3 = [gameDir stringByAppendingPathComponent:@"mods"];
        BOOL isDir3 = NO;
        if ([fm fileExistsAtPath:cand3 isDirectory:&isDir3] && isDir3) return cand3;
    }

    // Fallback: older layout Documents/game_data/<profile>/mods
    NSString *cand4 = [documents stringByAppendingPathComponent:[NSString stringWithFormat:@"game_data/%@/mods", profile]];
    BOOL isDir4 = NO;
    if ([fm fileExistsAtPath:cand4 isDirectory:&isDir4] && isDir4) return cand4;

    return nil;
}

#pragma mark - Scan

- (void)scanModsForProfile:(NSString *)profileName completion:(ModListHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *modsFolder = [self existingModsFolderForProfile:profileName];
        NSMutableArray<ModItem *> *items = [NSMutableArray array];
        if (modsFolder) {
            NSError *err = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:modsFolder error:&err];
            if (contents) {
                for (NSString *f in contents) {
                    if ([f hasSuffix:@".jar"] || [f hasSuffix:@".jar.disabled"] || [f hasSuffix:@".disabled"]) {
                        NSString *full = [modsFolder stringByAppendingPathComponent:f];
                        ModItem *m = [[ModItem alloc] initWithFilePath:full];
                        [items addObject:m];
                    }
                }
            }
        }
        [items sortUsingComparator:^NSComparisonResult(ModItem *a, ModItem *b) {
            return [a.displayName caseInsensitiveCompare:b.displayName];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(items);
        });
    });
}

#pragma mark - Helpers for jar extraction (crude but practical)

// Try to extract a PNG file embedded in the jar by searching path bytes and PNG signature.
// Writes the extracted PNG to destPath and returns YES on success.
- (BOOL)extractPNGFromJar:(NSString *)jarPath internalPath:(NSString *)internalPath destPath:(NSString *)destPath {
    if (!jarPath || !internalPath || !destPath) return NO;
    NSData *d = [NSData dataWithContentsOfFile:jarPath];
    if (!d) return NO;

    NSData *pathData = [internalPath dataUsingEncoding:NSUTF8StringEncoding];
    NSRange found = [d rangeOfData:pathData options:0 range:NSMakeRange(0, d.length)];
    if (found.location == NSNotFound) {
        // Try searching for just the basename
        NSString *basename = [internalPath lastPathComponent];
        NSData *bn = [basename dataUsingEncoding:NSUTF8StringEncoding];
        found = [d rangeOfData:bn options:0 range:NSMakeRange(0, d.length)];
        if (found.location == NSNotFound) return NO;
    }

    // After the path occurrence, search forward for PNG signature 0x89 0x50 0x4E 0x47
    const unsigned char pngSig[4] = {0x89, 0x50, 0x4E, 0x47};
    NSUInteger startSearch = found.location;
    NSUInteger idx = NSNotFound;
    for (NSUInteger i = startSearch; i + 4 < d.length; i++) {
        const unsigned char *bytes = d.bytes;
        if (bytes[i] == pngSig[0] && bytes[i+1] == pngSig[1] && bytes[i+2] == pngSig[2] && bytes[i+3] == pngSig[3]) {
            idx = i;
            break;
        }
    }
    if (idx == NSNotFound) return NO;

    // Find IEND chunk (49 45 4E 44) to determine end of PNG (include 12 bytes after IEND chunk)
    const unsigned char iendSig[4] = {0x49, 0x45, 0x4E, 0x44};
    NSUInteger endIdx = NSNotFound;
    for (NSUInteger i = idx; i + 4 < d.length; i++) {
        const unsigned char *bytes = d.bytes;
        if (bytes[i] == iendSig[0] && bytes[i+1] == iendSig[1] && bytes[i+2] == iendSig[2] && bytes[i+3] == iendSig[3]) {
            // IEND chunk length is 12 bytes: 4 (length) + 4 (IEND) + 4 (CRC) after 'IEND' position minus 4 for position?
            endIdx = i + 4 + 4; // include CRC (best-effort)
            break;
        }
    }
    if (endIdx == NSNotFound || endIdx <= idx) return NO;

    NSRange pngRange = NSMakeRange(idx, endIdx - idx);
    if (NSMaxRange(pngRange) > d.length) pngRange.length = d.length - pngRange.location;
    NSData *pngData = [d subdataWithRange:pngRange];
    if (!pngData || pngData.length < 8) return NO;

    NSError *err = nil;
    BOOL ok = [pngData writeToFile:destPath options:NSDataWritingAtomic error:&err];
    if (!ok) {
        return NO;
    }
    return YES;
}

#pragma mark - Metadata (local jar parsing and online fallback)

/*
 Behavior:
 - If onlineSearchEnabled == YES:
     1. Try online search first (Modrinth) using query:
         - If mod.isFabric (we can detect by parsing the jar briefly for fabric.mod.json "name" quickly), use "name" field as query.
         - Otherwise use basename (file name) as query.
     2. If online returns useful metadata (title/description/icon), use it.
     3. If online fails, fall back to local jar parsing.
 - If onlineSearchEnabled == NO (default):
     1. Try local jar parsing first (fabric.mod.json, mcmod.info).
     2. If local parsing yields metadata (name/description/icon/homepage/version), use it.
     3. Otherwise, fall back to Modrinth online search.
*/

- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *sha1 = [self sha1ForFileAtPath:mod.filePath];
        if (sha1) mod.fileSHA1 = sha1;

        // Helper block to parse jar locally (fabric.mod.json, mcmod.info)
        __block BOOL didLocal = NO;
        void (^localParseBlock)(void) = ^{
            NSData *data = [NSData dataWithContentsOfFile:mod.filePath];
            if (!data) return;
            NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!s) return;

            // Try fabric.mod.json
            NSRange fmRange = [s rangeOfString:@"fabric.mod.json"];
            if (fmRange.location != NSNotFound) {
                // find '{' after the occurrence
                NSRange braceRange = [s rangeOfString:@"{" options:0 range:NSMakeRange(fmRange.location, s.length - fmRange.location)];
                if (braceRange.location != NSNotFound) {
                    NSUInteger start = braceRange.location;
                    NSUInteger pos = start;
                    int depth = 0;
                    NSUInteger len = s.length;
                    while (pos < len) {
                        unichar c = [s characterAtIndex:pos];
                        if (c == '{') depth++;
                        else if (c == '}') {
                            depth--;
                            if (depth == 0) {
                                NSRange jsonRange = NSMakeRange(start, pos - start + 1);
                                NSString *jsonStr = [s substringWithRange:jsonRange];
                                NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                                NSError *jerr = nil;
                                id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jerr];
                                if (!jerr && [obj isKindOfClass:[NSDictionary class]]) {
                                    NSDictionary *d = obj;
                                    // name
                                    if (d[@"name"] && [d[@"name"] isKindOfClass:[NSString class]]) {
                                        mod.displayName = d[@"name"];
                                    }
                                    // description
                                    if (d[@"description"] && [d[@"description"] isKindOfClass:[NSString class]]) {
                                        mod.modDescription = d[@"description"];
                                    }
                                    // version
                                    if (d[@"version"] && [d[@"version"] isKindOfClass:[NSString class]]) {
                                        mod.version = d[@"version"];
                                    }
                                    // homepage / sources
                                    if (d[@"homepage"] && [d[@"homepage"] isKindOfClass:[NSString class]]) {
                                        mod.homepage = d[@"homepage"];
                                    } else if (d[@"sources"] && [d[@"sources"] isKindOfClass:[NSString class]]) {
                                        mod.homepage = d[@"sources"];
                                    }
                                    // icon path inside jar
                                    if (d[@"icon"] && [d[@"icon"] isKindOfClass:[NSString class]]) {
                                        NSString *iconPath = d[@"icon"];
                                        mod.iconPathInJar = iconPath;
                                        // attempt to extract PNG to cache
                                        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                                        NSString *modIconFolder = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
                                        if (![[NSFileManager defaultManager] fileExistsAtPath:modIconFolder]) {
                                            [[NSFileManager defaultManager] createDirectoryAtPath:modIconFolder withIntermediateDirectories:YES attributes:nil error:nil];
                                        }
                                        NSString *baseName = [[mod.filePath lastPathComponent] stringByDeletingPathExtension];
                                        NSString *destName = [NSString stringWithFormat:@"%@_%@", baseName, [iconPath lastPathComponent]];
                                        NSString *destPath = [modIconFolder stringByAppendingPathComponent:destName];
                                        BOOL extracted = [self extractPNGFromJar:mod.filePath internalPath:iconPath destPath:destPath];
                                        if (extracted) {
                                            mod.iconURL = [NSURL fileURLWithPath:destPath].absoluteString;
                                        }
                                    }
                                    // mark as fabric
                                    mod.isFabric = YES;
                                    didLocal = YES;
                                }
                                break;
                            }
                        }
                        pos++;
                    }
                }
            }

            // Try mcmod.info (Forge); very basic JSON array parse
            if (!didLocal) {
                NSRange mcRange = [s rangeOfString:@"mcmod.info"];
                if (mcRange.location != NSNotFound) {
                    NSRange arrStart = [s rangeOfString:@"[" options:0 range:NSMakeRange(mcRange.location, s.length - mcRange.location)];
                    if (arrStart.location != NSNotFound) {
                        NSUInteger start = arrStart.location;
                        NSUInteger pos = start;
                        NSUInteger len = s.length;
                        int depth = 0;
                        while (pos < len) {
                            unichar c = [s characterAtIndex:pos];
                            if (c == '[') depth++;
                            else if (c == ']') {
                                depth--;
                                if (depth == 0) {
                                    NSRange jsonRange = NSMakeRange(start, pos - start + 1);
                                    NSString *jsonStr = [s substringWithRange:jsonRange];
                                    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                                    NSError *jerr = nil;
                                    id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jerr];
                                    if (!jerr && [obj isKindOfClass:[NSArray class]]) {
                                        NSArray *arr = obj;
                                        if (arr.count > 0 && [arr[0] isKindOfClass:[NSDictionary class]]) {
                                            NSDictionary *d = arr[0];
                                            if (d[@"name"]) mod.displayName = d[@"name"];
                                            if (d[@"description"]) mod.modDescription = d[@"description"];
                                            if (d[@"version"]) mod.version = d[@"version"];
                                            didLocal = YES;
                                        }
                                    }
                                    break;
                                }
                            }
                            pos++;
                        }
                    }
                }
            }
        };

        // Helper to perform Modrinth search (returns YES if it populated meaningful fields)
        __block BOOL didRemote = NO;
        void (^remoteSearchBlock)(void) = ^{
            // choose query depending on mod.isFabric or filename; we try to detect fabric quickly
            NSString *quickName = mod.displayName ?: [mod basename];
            // If we haven't parsed locally and mod might be fabric (try a quick local search for fabric.mod.json)
            if (!mod.isFabric) {
                NSData *data = [NSData dataWithContentsOfFile:mod.filePath];
                if (data) {
                    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if (s && [s rangeOfString:@"fabric.mod.json"].location != NSNotFound) {
                        // attempt to extract name field quickly
                        NSRange nameRange = [s rangeOfString:@"\"name\"\\s*:\\s*\"" options:NSRegularExpressionSearch];
                        if (nameRange.location != NSNotFound) {
                            NSUInteger start = NSMaxRange(nameRange);
                            NSUInteger pos = start;
                            NSMutableString *buf = [NSMutableString string];
                            while (pos < s.length) {
                                unichar c = [s characterAtIndex:pos++];
                                if (c == '\"') break;
                                [buf appendFormat:@"%C", c];
                            }
                            if (buf.length) quickName = buf;
                        }
                    }
                }
            }

            NSString *query = [quickName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            if (!query) return;
            NSString *searchURL = [NSString stringWithFormat:@"https://api.modrinth.com/v2/search?query=%@&limit=5", query];
            NSURL *urlObj = [NSURL URLWithString:searchURL];
            if (!urlObj) return;
            NSData *d = [NSData dataWithContentsOfURL:urlObj];
            if (!d) return;
            NSError *jsonErr;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:&jsonErr];
            if (jsonErr || ![json isKindOfClass:[NSDictionary class]]) return;
            NSArray *hits = json[@"hits"];
            if (hits.count == 0) return;
            NSDictionary *first = hits.firstObject;
            NSString *projectId = first[@"project_id"];
            NSString *desc = first[@"description"] ?: first[@"title"];
            __block NSString *iconUrl = nil;
            if (projectId) {
                NSString *projURL = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", projectId];
                NSData *projData = [NSData dataWithContentsOfURL:[NSURL URLWithString:projURL]];
                if (projData) {
                    NSDictionary *projJson = [NSJSONSerialization JSONObjectWithData:projData options:0 error:nil];
                    if ([projJson isKindOfClass:[NSDictionary class]]) {
                        iconUrl = projJson[@"icon_url"] ?: projJson[@"icon"];
                        if (!iconUrl) {
                            NSDictionary *icons = projJson[@"icons"];
                            if ([icons isKindOfClass:[NSDictionary class]]) {
                                iconUrl = icons[@"512"] ?: icons[@"256"] ?: icons[@"128"];
                            }
                        }
                        if (!desc) desc = projJson[@"description"];
                    }
                }
            }
            // Fill fields
            if (first[@"title"] && [first[@"title"] isKindOfClass:[NSString class]]) {
                mod.displayName = first[@"title"];
            }
            if (desc && [desc isKindOfClass:[NSString class]]) mod.modDescription = desc;
            if (iconUrl && [iconUrl isKindOfClass:[NSString class]]) mod.iconURL = iconUrl;
            didRemote = YES;
        };

        // Execution flow based on onlineSearchEnabled
        if (self.onlineSearchEnabled) {
            // remote first
            @try { remoteSearchBlock(); } @catch (...) {}
            if (!didRemote) {
                @try { localParseBlock(); } @catch (...) {}
            }
        } else {
            // local first
            @try { localParseBlock(); } @catch (...) {}
            if (!didLocal) {
                @try { remoteSearchBlock(); } @catch (...) {}
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(mod, nil);
        });
    });
}

#pragma mark - File ops

- (BOOL)toggleEnableForMod:(ModItem *)mod error:(NSError **)error {
    NSString *path = mod.filePath;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (mod.disabled) {
        NSString *newName = [mod.fileName stringByReplacingOccurrencesOfString:@".disabled" withString:@""];
        NSString *newPath = [[mod.filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];
        BOOL ok = [fm moveItemAtPath:path toPath:newPath error:error];
        if (ok) {
            mod.filePath = newPath;
            mod.fileName = newName;
            mod.disabled = NO;
        }
        return ok;
    } else {
        NSString *newName = [mod.fileName stringByAppendingString:@".disabled"];
        NSString *newPath = [[mod.filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];
        BOOL ok = [fm moveItemAtPath:path toPath:newPath error:error];
        if (ok) {
            mod.filePath = newPath;
            mod.fileName = newName;
            mod.disabled = YES;
        }
        return ok;
    }
}

- (BOOL)deleteMod:(ModItem *)mod error:(NSError **)error {
    return [[NSFileManager defaultManager] removeItemAtPath:mod.filePath error:error];
}

#pragma mark - Helpers

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

@end