//
//  ModService.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Revised: add private declarations to fix compile errors and keep metadata + unzip logic.
//

#import "ModService.h"
#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIKit.h>
#import "PLProfiles.h"
#import "ModItem.h"
#import "UnzipKit.h" // 本仓库有 UnzipKit

// Private methods (class extension) so compiler knows about selectors used inside implementation
@interface ModService ()
// TOML parser used internally
- (NSDictionary<NSString *, NSString *> *)parseFirstModsTableFromTomlString:(NSString *)s;
@end

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

#pragma mark - Unzip helpers (uses UnzipKit instance API)

- (nullable NSData *)readFileFromJar:(NSString *)jarPath entryName:(NSString *)entryName {
    if (!jarPath || !entryName) return nil;
    NSError *err = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:jarPath error:&err];
    if (!archive || err) return nil;

    NSArray<NSString *> *tryList = @[
        entryName,
        [entryName stringByReplacingOccurrencesOfString:@"\\" withString:@"/"],
        [entryName stringByReplacingOccurrencesOfString:@"./" withString:@""],
        [NSString stringWithFormat:@"/%@", entryName],
        [entryName lastPathComponent]
    ];

    for (NSString *tryEntry in tryList) {
        if (!tryEntry || tryEntry.length == 0) continue;
        NSError *e = nil;
        NSData *data = [archive extractDataFromFile:tryEntry error:&e];
        if (data && data.length > 0) return data;
    }

    NSError *enumErr = nil;
    NSArray<UZKFileInfo *> *infos = [archive listFileInfo:&enumErr];
    if (!infos) return nil;

    for (UZKFileInfo *info in infos) {
        NSString *entryPath = info.filename ?: @"";
        NSString *normalized = [entryPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        if ([normalized caseInsensitiveCompare:entryName] == NSOrderedSame ||
            [[normalized lastPathComponent] caseInsensitiveCompare:entryName] == NSOrderedSame ||
            [[normalized lastPathComponent] isEqualToString:entryName]) {
            NSError *e = nil;
            NSData *data = [archive extractDataFromFile:entryPath error:&e];
            if (data && data.length > 0) return data;
        }
    }
    return nil;
}

- (nullable NSString *)extractFirstMatchingImageFromJar:(NSString *)jarPath candidates:(NSArray<NSString *> *)candidates baseName:(NSString *)baseName {
    if (!jarPath) return nil;
    for (NSString *cand in candidates) {
        if (!cand || cand.length == 0) continue;
        NSData *d = [self readFileFromJar:jarPath entryName:cand];
        if (d && d.length > 8) {
            const unsigned char *bytes = d.bytes;
            BOOL isPNG = (d.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47);
            NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *iconsDir = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:iconsDir]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:iconsDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *safeBase = [[baseName stringByReplacingOccurrencesOfString:@" " withString:@"_"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            NSString *fname = [NSString stringWithFormat:@"%@_%@", safeBase, [cand lastPathComponent]];
            if (![fname.pathExtension length]) {
                fname = [fname stringByAppendingPathExtension:(isPNG ? @"png":@"dat")];
            }
            NSString *dest = [iconsDir stringByAppendingPathComponent:fname];
            NSError *err = nil;
            if ([d writeToFile:dest options:NSDataWritingAtomic error:&err]) {
                return [NSURL fileURLWithPath:dest].absoluteString;
            }
        }
    }
    return nil;
}

#pragma mark - TOML lightweight parser (private helper)

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

#pragma mark - Mods folder detection & scan (robust)

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
    } @catch (NSException *ex) { }

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

    // Fallback broad search (may be slower; only used if all above fail)
    NSArray<NSString *> *searchRoots = @[documents, NSHomeDirectory()];
    for (NSString *root in searchRoots) {
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:root];
        NSString *entry;
        int depth = 0;
        while ((entry = [enumerator nextObject]) && depth < 1000) {
            depth++;
            if ([entry.lastPathComponent.lowercaseString isEqualToString:@"mods"]) {
                NSString *full = [root stringByAppendingPathComponent:entry];
                BOOL isDir = NO;
                if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) {
                    NSArray *sub = [fm contentsOfDirectoryAtPath:full error:nil];
                    for (NSString *fn in sub) {
                        NSString *lower = fn.lowercaseString;
                        if ([lower hasSuffix:@".jar"] || [lower hasSuffix:@".jar.disabled"]) {
                            return full;
                        }
                    }
                }
            }
        }
    }

    return nil;
}

- (void)scanModsForProfile:(NSString *)profileName completion:(ModListHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *modsFolder = [self existingModsFolderForProfile:profileName];
        NSMutableArray<ModItem *> *items = [NSMutableArray array];
        if (modsFolder) {
            NSError *err = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:modsFolder error:&err];
            if (contents) {
                for (NSString *f in contents) {
                    NSString *lower = f.lowercaseString;
                    if ([lower hasSuffix:@".jar"] || [lower hasSuffix:@".jar.disabled"] || [lower hasSuffix:@".disabled"]) {
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

#pragma mark - Metadata fetch (zip-based + online optional)

- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *sha1 = [self sha1ForFileAtPath:mod.filePath];
        if (sha1) mod.fileSHA1 = sha1;

        __block BOOL gotLocal = NO;

        // 1) fabric.mod.json
        NSData *fabricJsonData = [self readFileFromJar:mod.filePath entryName:@"fabric.mod.json"];
        if (!fabricJsonData) {
            fabricJsonData = [self readFileFromJar:mod.filePath entryName:@"META-INF/fabric.mod.json"];
        }
        if (fabricJsonData) {
            NSError *jerr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:fabricJsonData options:0 error:&jerr];
            if (!jerr && [obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *d = obj;
                if (d[@"name"] && [d[@"name"] isKindOfClass:[NSString class]]) mod.displayName = d[@"name"];
                if (d[@"description"] && [d[@"description"] isKindOfClass:[NSString class]]) mod.modDescription = d[@"description"];
                if (d[@"version"] && [d[@"version"] isKindOfClass:[NSString class]]) mod.version = d[@"version"];

                // homepage may be at top-level or under contact.homepage
                if (d[@"homepage"] && [d[@"homepage"] isKindOfClass:[NSString class]]) mod.homepage = d[@"homepage"];
                else if (d[@"contact"] && [d[@"contact"] isKindOfClass:[NSDictionary class]]) {
                    NSString *hp = d[@"contact"][@"homepage"];
                    if (hp && [hp isKindOfClass:[NSString class]] && hp.length) mod.homepage = hp;
                }

                if (d[@"sources"] && [d[@"sources"] isKindOfClass:[NSString class]]) mod.sources = d[@"sources"];

                if (d[@"icon"] && [d[@"icon"] isKindOfClass:[NSString class]]) {
                    NSString *iconPath = d[@"icon"];
                    NSArray *cands = @[
                        iconPath ?: @"",
                        [iconPath stringByReplacingOccurrencesOfString:@"./" withString:@""],
                        [NSString stringWithFormat:@"assets/%@", iconPath ?: @""],
                        [NSString stringWithFormat:@"assets/%@/%@", [mod.basename lowercaseString], [iconPath lastPathComponent] ?: @""]
                    ];
                    NSString *cached = [self extractFirstMatchingImageFromJar:mod.filePath candidates:cands baseName:mod.basename];
                    if (cached) mod.iconURL = cached;
                }

                mod.isFabric = YES;
                gotLocal = YES;
            }
        }

        // 2) mods.toml / neoforge.mods.toml
        if (!gotLocal) {
            NSData *modsTomlData = [self readFileFromJar:mod.filePath entryName:@"META-INF/mods.toml"];
            if (!modsTomlData) modsTomlData = [self readFileFromJar:mod.filePath entryName:@"mods.toml"];
            if (!modsTomlData) modsTomlData = [self readFileFromJar:mod.filePath entryName:@"neoforge.mods.toml"];
            if (modsTomlData) {
                NSString *s = [[NSString alloc] initWithData:modsTomlData encoding:NSUTF8StringEncoding];
                if (!s) s = [[NSString alloc] initWithData:modsTomlData encoding:NSISOLatin1StringEncoding];
                if (s) {
                    NSDictionary *fields = [self parseFirstModsTableFromTomlString:s];
                    if (fields.count > 0) {
                        NSString *dname = fields[@"displayName"] ?: fields[@"name"];
                        if (dname.length) mod.displayName = dname;
                        if (fields[@"description"]) mod.modDescription = fields[@"description"];
                        if (fields[@"version"]) mod.version = fields[@"version"];
                        if (fields[@"displayURL"]) mod.homepage = fields[@"displayURL"];
                        else if (fields[@"homepage"]) mod.homepage = fields[@"homepage"];

                        if (fields[@"logoFile"]) {
                            NSString *logo = fields[@"logoFile"];
                            NSArray *cands = @[
                                logo ?: @"",
                                [NSString stringWithFormat:@"assets/%@/%@", [[mod.basename lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"_"], logo ?: @""],
                                [logo lastPathComponent] ?: @""
                            ];
                            NSString *cached = [self extractFirstMatchingImageFromJar:mod.filePath candidates:cands baseName:mod.basename];
                            if (cached) mod.iconURL = cached;
                        }
                        if ([self readFileFromJar:mod.filePath entryName:@"neoforge.mods.toml"]) mod.isNeoForge = YES;
                        else mod.isForge = YES;
                        gotLocal = YES;
                    }
                }
            }
        }

        // 3) mcmod.info (old)
        if (!gotLocal) {
            NSData *mcData = [self readFileFromJar:mod.filePath entryName:@"mcmod.info"];
            if (mcData) {
                NSError *jerr = nil;
                id obj = [NSJSONSerialization JSONObjectWithData:mcData options:0 error:&jerr];
                if (!jerr && [obj isKindOfClass:[NSArray class]]) {
                    NSArray *arr = obj;
                    if (arr.count > 0 && [arr[0] isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *d = arr[0];
                        if (d[@"name"]) mod.displayName = d[@"name"];
                        if (d[@"description"]) mod.modDescription = d[@"description"];
                        if (d[@"version"]) mod.version = d[@"version"];
                        gotLocal = YES;
                    }
                } else {
                    NSString *s = [[NSString alloc] initWithData:mcData encoding:NSUTF8StringEncoding];
                    if (s && s.length) {
                        NSRange nameRange = [s rangeOfString:@"name\"\\s*:\\s*\"" options:NSRegularExpressionSearch];
                        if (nameRange.location != NSNotFound) {
                            NSUInteger start = NSMaxRange(nameRange);
                            NSUInteger pos = start;
                            NSMutableString *buf = [NSMutableString string];
                            while (pos < s.length) {
                                unichar c = [s characterAtIndex:pos++];
                                if (c == '\"') break;
                                [buf appendFormat:@"%C", c];
                            }
                            if (buf.length) { mod.displayName = buf; gotLocal = YES; }
                        }
                    }
                }
            }
        }

        // Online fallback search
        if (!gotLocal && self.onlineSearchEnabled) {
            NSString *searchKey = nil;
            if (mod.isFabric && mod.displayName.length > 0) {
                searchKey = mod.displayName;
            } else if ((mod.isForge || mod.isNeoForge)) {
                searchKey = [mod basename];
            } else {
                searchKey = mod.displayName ?: [mod basename];
            }
            NSString *query = [searchKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *q = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            if (q.length) {
                NSString *searchURL = [NSString stringWithFormat:@"https://api.modrinth.com/v2/search?query=%@&limit=5", q];
                NSData *d = [NSData dataWithContentsOfURL:[NSURL URLWithString:searchURL]];
                if (d) {
                    NSError *jsonErr;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:&jsonErr];
                    if (!jsonErr && [json isKindOfClass:[NSDictionary class]]) {
                        NSArray *hits = json[@"hits"];
                        if (hits.count > 0) {
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
                            if (first[@"title"] && [first[@"title"] isKindOfClass:[NSString class]]) mod.displayName = first[@"title"];
                            if (desc && [desc isKindOfClass:[NSString class]]) mod.modDescription = desc;
                            if (iconUrl && [iconUrl isKindOfClass:[NSString class]]) mod.iconURL = iconUrl;
                        }
                    }
                }
            }
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
