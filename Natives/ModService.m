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
#import "ModItem.h"

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

#pragma mark - Jar extraction (best-effort)

- (BOOL)extractPNGFromJar:(NSString *)jarPath internalPath:(NSString *)internalPath destPath:(NSString *)destPath {
    if (!jarPath || !internalPath || !destPath) return NO;
    NSData *d = [NSData dataWithContentsOfFile:jarPath];
    if (!d) return NO;

    NSData *pathData = [internalPath dataUsingEncoding:NSUTF8StringEncoding];
    NSRange found = [d rangeOfData:pathData options:0 range:NSMakeRange(0, d.length)];
    if (found.location == NSNotFound) {
        NSString *basename = [internalPath lastPathComponent];
        NSData *bn = [basename dataUsingEncoding:NSUTF8StringEncoding];
        found = [d rangeOfData:bn options:0 range:NSMakeRange(0, d.length)];
        if (found.location == NSNotFound) return NO;
    }

    const unsigned char pngSig[4] = {0x89, 0x50, 0x4E, 0x47};
    NSUInteger startSearch = found.location;
    NSUInteger idx = NSNotFound;
    const unsigned char *bytes = d.bytes;
    for (NSUInteger i = startSearch; i + 4 < d.length; i++) {
        if (bytes[i] == pngSig[0] && bytes[i+1] == pngSig[1] && bytes[i+2] == pngSig[2] && bytes[i+3] == pngSig[3]) {
            idx = i;
            break;
        }
    }
    if (idx == NSNotFound) return NO;

    const unsigned char iendSig[4] = {0x49, 0x45, 0x4E, 0x44};
    NSUInteger endIdx = NSNotFound;
    for (NSUInteger i = idx; i + 12 < d.length; i++) {
        if (bytes[i] == iendSig[0] && bytes[i+1] == iendSig[1] && bytes[i+2] == iendSig[2] && bytes[i+3] == iendSig[3]) {
            endIdx = i + 8;
            break;
        }
    }
    if (endIdx == NSNotFound || endIdx <= idx) {
        endIdx = d.length;
    }

    NSRange pngRange = NSMakeRange(idx, endIdx - idx);
    if (NSMaxRange(pngRange) > d.length) pngRange.length = d.length - pngRange.location;
    NSData *pngData = [d subdataWithRange:pngRange];
    if (!pngData || pngData.length < 8) return NO;
    NSError *err = nil;
    BOOL ok = [pngData writeToFile:destPath options:NSDataWritingAtomic error:&err];
    return ok;
}

#pragma mark - Mods folder detection

- (nullable NSString *)existingModsFolderForProfile:(NSString *)profileName {
    NSString *profile = profileName.length ? profileName : @"default";
    NSFileManager *fm = NSFileManager.defaultManager;

    @try {
        NSDictionary *profiles = PLProfiles.current.profiles;
        NSDictionary *prof = profiles[profile];
        if ([prof isKindOfClass:[NSDictionary class]]) {
            NSString *gameDir = prof[@"gameDir"];
            if ([gameDir isKindOfClass:[NSString class]] && gameDir.length > 0) {
                if ([gameDir hasPrefix:@"./"]) {
                    const char *gameDirC = getenv("POJAV_GAME_DIR");
                    if (gameDirC) {
                        NSString *pojGameDir = [NSString stringWithUTF8String:gameDirC];
                        NSString *rel = [gameDir substringFromIndex:2];
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
                    NSString *candMods = [gameDir stringByAppendingPathComponent:@"mods"];
                    BOOL isDir = NO;
                    if ([fm fileExistsAtPath:candMods isDirectory:&isDir] && isDir) return candMods;
                    if ([fm fileExistsAtPath:gameDir isDirectory:&isDir] && isDir) {
                        NSString *cand2 = [gameDir stringByAppendingPathComponent:@"mods"];
                        if ([fm fileExistsAtPath:cand2 isDirectory:&isDir] && isDir) return cand2;
                    }
                } else {
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
        // ignore
    }

    const char *pojHomeC = getenv("POJAV_HOME");
    if (pojHomeC) {
        NSString *pojHome = [NSString stringWithUTF8String:pojHomeC];
        NSString *cand1 = [pojHome stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", profile]];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:cand1 isDirectory:&isDir] && isDir) return cand1;
    }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    NSString *cand2 = [documents stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@/mods", profile]];
    BOOL isDir2 = NO;
    if ([fm fileExistsAtPath:cand2 isDirectory:&isDir2] && isDir2) return cand2;

    const char *gameDirC = getenv("POJAV_GAME_DIR");
    if (gameDirC) {
        NSString *gameDir = [NSString stringWithUTF8String:gameDirC];
        NSString *cand3 = [gameDir stringByAppendingPathComponent:@"mods"];
        BOOL isDir3 = NO;
        if ([fm fileExistsAtPath:cand3 isDirectory:&isDir3] && isDir3) return cand3;
    }

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

#pragma mark - TOML helper (lightweight)

- (NSDictionary<NSString *, NSString *> *)parseFirstModsTableFromTomlString:(NSString *)s {
    if (!s) return @{};
    NSRange modsRange = [s rangeOfString:@"[[mods]]"];
    if (modsRange.location == NSNotFound) {
        modsRange = [s rangeOfString:@"[mods]"];
        if (modsRange.location == NSNotFound) return @{};
    }
    NSUInteger start = modsRange.location;
    NSUInteger end = s.length;
    NSRange nextSection = [s rangeOfString:@"[[" options:0 range:NSMakeRange(start+1, s.length - (start+1))];
    if (nextSection.location != NSNotFound) end = nextSection.location;
    NSString *block = [s substringWithRange:NSMakeRange(start, end - start)];
    NSMutableDictionary *out = [NSMutableDictionary dictionary];

    NSArray<NSString *> *keys = @[@"displayName", @"version", @"description", @"logoFile", @"displayURL", @"authors", @"homepage", @"url"];
    for (NSString *key in keys) {
        NSString *patternTriple = [NSString stringWithFormat:@"%@\\s*=\\s*([\"']{3})([\\s\\S]*?)\\1", key];
        NSRegularExpression *reTriple = [NSRegularExpression regularExpressionWithPattern:patternTriple options:NSRegularExpressionCaseInsensitive error:nil];
        NSTextCheckingResult *rTriple = [reTriple firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
        if (rTriple) {
            NSRange valRange = [rTriple rangeAtIndex:2];
            if (valRange.location != NSNotFound) {
                NSString *val = [block substringWithRange:valRange];
                if (val.length) out[key] = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                continue;
            }
        }
        NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*([\"'])(.*?)\\1", key];
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
        NSTextCheckingResult *r = [re firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
        if (r) {
            NSRange valRange = [r rangeAtIndex:2];
            if (valRange.location != NSNotFound) {
                NSString *val = [block substringWithRange:valRange];
                if (val.length) out[key] = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                continue;
            }
        }
        if ([key isEqualToString:@"authors"]) {
            NSString *patternArr = @"authors\\s*=\\s*\\[([^\\]]+)\\]";
            NSRegularExpression *reArr = [NSRegularExpression regularExpressionWithPattern:patternArr options:NSRegularExpressionCaseInsensitive error:nil];
            NSTextCheckingResult *ra = [reArr firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
            if (ra) {
                NSRange inner = [ra rangeAtIndex:1];
                if (inner.location != NSNotFound) {
                    NSString *arr = [block substringWithRange:inner];
                    NSRegularExpression *reQ = [NSRegularExpression regularExpressionWithPattern:@"[\"'](.*?)[\"']" options:0 error:nil];
                    NSTextCheckingResult *rq = [reQ firstMatchInString:arr options:0 range:NSMakeRange(0, arr.length)];
                    if (rq) {
                        NSString *val = [arr substringWithRange:[rq rangeAtIndex:1]];
                        if (val.length) out[key] = val;
                    }
                }
            }
        }
    }
    return out;
}

#pragma mark - Metadata fetch (local-first unless onlineSearchEnabled is explicitly YES)

- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *sha1 = [self sha1ForFileAtPath:mod.filePath];
        if (sha1) mod.fileSHA1 = sha1;

        __block BOOL gotLocal = NO;
        NSData *jarData = [NSData dataWithContentsOfFile:mod.filePath];
        NSString *jarText = nil;
        if (jarData) jarText = [[NSString alloc] initWithData:jarData encoding:NSUTF8StringEncoding];

        // LOCAL PARSING: fabric.mod.json
        if (jarText && [jarText rangeOfString:@"fabric.mod.json"].location != NSNotFound) {
            NSRange fmRange = [jarText rangeOfString:@"fabric.mod.json"];
            NSRange braceRange = [jarText rangeOfString:@"{" options:0 range:NSMakeRange(fmRange.location, jarText.length - fmRange.location)];
            if (braceRange.location != NSNotFound) {
                NSUInteger start = braceRange.location;
                NSUInteger pos = start;
                int depth = 0;
                NSUInteger len = jarText.length;
                while (pos < len) {
                    unichar c = [jarText characterAtIndex:pos];
                    if (c == '{') depth++;
                    else if (c == '}') {
                        depth--;
                        if (depth == 0) {
                            NSRange jsonRange = NSMakeRange(start, pos - start + 1);
                            NSString *jsonStr = [jarText substringWithRange:jsonRange];
                            NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                            NSError *jerr = nil;
                            id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jerr];
                            if (!jerr && [obj isKindOfClass:[NSDictionary class]]) {
                                NSDictionary *d = obj;
                                if (d[@"name"]) mod.displayName = d[@"name"];
                                if (d[@"description"]) mod.modDescription = d[@"description"];
                                if (d[@"version"]) mod.version = d[@"version"];
                                if (d[@"homepage"] && [d[@"homepage"] isKindOfClass:[NSString class]]) mod.homepage = d[@"homepage"];
                                else if (d[@"sources"] && [d[@"sources"] isKindOfClass:[NSString class]]) mod.sources = d[@"sources"];
                                if (d[@"icon"] && [d[@"icon"] isKindOfClass:[NSString class]]) {
                                    mod.iconPathInJar = d[@"icon"];
                                    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                                    NSString *iconsDir = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
                                    if (![[NSFileManager defaultManager] fileExistsAtPath:iconsDir]) {
                                        [[NSFileManager defaultManager] createDirectoryAtPath:iconsDir withIntermediateDirectories:YES attributes:nil error:nil];
                                    }
                                    NSString *dest = [iconsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", [mod.basename stringByReplacingOccurrencesOfString:@" " withString:@"_"], [mod.iconPathInJar lastPathComponent]]];
                                    if ([self extractPNGFromJar:mod.filePath internalPath:mod.iconPathInJar destPath:dest]) {
                                        mod.iconURL = [NSURL fileURLWithPath:dest].absoluteString;
                                    }
                                }
                                mod.isFabric = YES;
                                gotLocal = YES;
                            }
                            break;
                        }
                    }
                    pos++;
                }
            }
        }

        // LOCAL PARSING: mods.toml / neoforge.mods.toml (Forge / NeoForge)
        if (!gotLocal && jarText) {
            BOOL hasModsToml = ([jarText rangeOfString:@"mods.toml"].location != NSNotFound) || ([jarText rangeOfString:@"neoforge.mods.toml"].location != NSNotFound);
            if (hasModsToml && ([jarText rangeOfString:@"[[mods]]"].location != NSNotFound || [jarText rangeOfString:@"[mods]"].location != NSNotFound)) {
                NSDictionary *fields = [self parseFirstModsTableFromTomlString:jarText];
                if (fields.count > 0) {
                    NSString *dname = fields[@"displayName"] ?: fields[@"name"];
                    if (dname.length) mod.displayName = dname;
                    if (fields[@"description"]) mod.modDescription = fields[@"description"];
                    if (fields[@"version"]) mod.version = fields[@"version"];
                    if (fields[@"displayURL"]) mod.homepage = fields[@"displayURL"];
                    if (fields[@"homepage"]) mod.homepage = fields[@"homepage"];
                    if (fields[@"logoFile"]) {
                        NSString *logo = fields[@"logoFile"];
                        NSArray *cands = @[
                            logo ?: @"",
                            [NSString stringWithFormat:@"assets/%@/%@", [[mod basename] lowercaseString], logo ?: @""],
                            [NSString stringWithFormat:@"assets/%@/%@", [[[mod basename] lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"_"], logo ?: @""],
                            [logo lastPathComponent] ?: @""
                        ];
                        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                        NSString *iconsDir = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
                        if (![[NSFileManager defaultManager] fileExistsAtPath:iconsDir]) {
                            [[NSFileManager defaultManager] createDirectoryAtPath:iconsDir withIntermediateDirectories:YES attributes:nil error:nil];
                        }
                        for (NSString *p in cands) {
                            if (!p || p.length == 0) continue;
                            NSString *dest = [iconsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", [[mod basename] stringByReplacingOccurrencesOfString:@" " withString:@"_"], [p lastPathComponent]]];
                            if ([self extractPNGFromJar:mod.filePath internalPath:p destPath:dest]) {
                                mod.iconURL = [NSURL fileURLWithPath:dest].absoluteString;
                                mod.iconPathInJar = p;
                                break;
                            }
                        }
                    }
                    if ([jarText rangeOfString:@"neoforge"].location != NSNotFound || [jarText rangeOfString:@"neoforge.mods.toml"].location != NSNotFound) {
                        mod.isNeoForge = YES;
                    } else {
                        mod.isForge = YES;
                    }
                    gotLocal = YES;
                }
            }
        }

        // LOCAL PARSING: mcmod.info (older Forge)
        if (!gotLocal && jarText) {
            NSRange mcRange = [jarText rangeOfString:@"mcmod.info"];
            if (mcRange.location != NSNotFound) {
                NSRange arrStart = [jarText rangeOfString:@"[" options:0 range:NSMakeRange(mcRange.location, jarText.length - mcRange.location)];
                if (arrStart.location != NSNotFound) {
                    NSUInteger start = arrStart.location;
                    NSUInteger pos = start;
                    NSUInteger len = jarText.length;
                    int depth = 0;
                    while (pos < len) {
                        unichar c = [jarText characterAtIndex:pos];
                        if (c == '[') depth++;
                        else if (c == ']') {
                            depth--;
                            if (depth == 0) {
                                NSRange jsonRange = NSMakeRange(start, pos - start + 1);
                                NSString *jsonStr = [jarText substringWithRange:jsonRange];
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
                                        gotLocal = YES;
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

        // REMOTE fallback: only if the user explicitly enabled online search
        __block BOOL didRemote = NO;
        void (^remoteSearchBlock)(void) = ^{
            NSString *query = mod.displayName ?: [mod basename];
            query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *q = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            if (!q) return;
            NSString *searchURL = [NSString stringWithFormat:@"https://api.modrinth.com/v2/search?query=%@&limit=5", q];
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
            if (first[@"title"] && [first[@"title"] isKindOfClass:[NSString class]]) {
                mod.displayName = first[@"title"];
            }
            if (desc && [desc isKindOfClass:[NSString class]]) mod.modDescription = desc;
            if (iconUrl && [iconUrl isKindOfClass:[NSString class]]) mod.iconURL = iconUrl;
            didRemote = YES;
        };

        if (self.onlineSearchEnabled) {
            @try { remoteSearchBlock(); } @catch (...) { /* ignore */ }
        } else {
            // onlineSearchEnabled == NO -> do NOT perform any network requests
            // Rely only on the local parsing results above
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(mod, nil);
        });
    });
}

#pragma mark - File operations

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

@end
