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

#pragma mark - Helpers (sha, icon cache)

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

#pragma mark - Jar extraction helper (PNG from jar)

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
            // include end of IEND chunk + CRC (12 bytes total after chunk start is not exact but best-effort)
            endIdx = i + 8; // try to include reasonable tail
            break;
        }
    }
    if (endIdx == NSNotFound || endIdx <= idx) {
        // fallback: take to EOF
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

#pragma mark - TOML parsing (basic)

/*
  Very small TOML extractor: finds the first [[mods]] block and extracts keys by regex:
    displayName = "..."
    version = "..."
    description = """...""" or '...' or "..."
    logoFile = "..."
    displayURL = "..."
    authors = "..." or authors = ["a","b"]
  This is not a full TOML parser; for robust behavior prefer to read mods.toml from jar via a zip library and parse with a TOML parser.
*/

- (NSDictionary<NSString *, NSString *> *)parseFirstModsTableFromTomlString:(NSString *)s {
    if (!s) return @{};
    NSRange modsRange = [s rangeOfString:@"[[mods]]"];
    if (modsRange.location == NSNotFound) {
        // also accept [mods] (loose)
        modsRange = [s rangeOfString:@"[mods]"];
        if (modsRange.location == NSNotFound) return @{};
    }
    NSUInteger start = modsRange.location;
    // limit the parsing area reasonably
    NSUInteger end = s.length;
    // stop at next double-bracket section or EOF
    NSRange nextSection = [s rangeOfString:@"[[" options:0 range:NSMakeRange(start+1, s.length - (start+1))];
    if (nextSection.location != NSNotFound) end = nextSection.location;
    NSString *block = [s substringWithRange:NSMakeRange(start, end - start)];

    NSMutableDictionary *out = [NSMutableDictionary dictionary];

    // helper to search key = "val" or key = 'val' or key = """val""" or key = '''val''' or key = [ ... ]
    NSArray<NSString *> *keys = @[@"displayName", @"version", @"description", @"logoFile", @"displayURL", @"authors", @"url", @"displayURL", @"homepage"];
    for (NSString *key in keys) {
        // triple-quote strings
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
        // single/double quoted
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
        // authors as array: authors = ["name", ...]
        if ([key isEqualToString:@"authors"]) {
            NSString *patternArr = @"authors\\s*=\\s*\\[([^\\]]+)\\]";
            NSRegularExpression *reArr = [NSRegularExpression regularExpressionWithPattern:patternArr options:NSRegularExpressionCaseInsensitive error:nil];
            NSTextCheckingResult *ra = [reArr firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
            if (ra) {
                NSRange inner = [ra rangeAtIndex:1];
                if (inner.location != NSNotFound) {
                    NSString *arr = [block substringWithRange:inner];
                    // pick first quoted entry
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

#pragma mark - Metadata fetch (local TOML/JSON + remote fallback)

- (void)fetchMetadataForMod:(ModItem *)mod completion:(ModMetadataHandler)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *sha1 = [self sha1ForFileAtPath:mod.filePath];
        if (sha1) mod.fileSHA1 = sha1;

        __block BOOL gotLocal = NO;

        // Read jar bytes once for local heuristics (avoid repeated disk reads)
        NSData *jarData = [NSData dataWithContentsOfFile:mod.filePath];
        NSString *jarText = nil;
        if (jarData) {
            jarText = [[NSString alloc] initWithData:jarData encoding:NSUTF8StringEncoding];
        }

        // 1) fabric.mod.json (existing approach)
        if (jarText && [jarText rangeOfString:@"fabric.mod.json"].location != NSNotFound) {
            // attempt to parse JSON block (same crude method as before)
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
                                    // try to extract
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

        // 2) mods.toml or neoforge.mods.toml (Forge / NeoForge)
        if (!gotLocal && jarText) {
            BOOL foundForgeToml = NO;
            NSRange r1 = [jarText rangeOfString:@"mods.toml"];
            NSRange r2 = [jarText rangeOfString:@"neoforge.mods.toml"];
            if (r1.location != NSNotFound) foundForgeToml = YES;
            if (r2.location != NSNotFound) foundForgeToml = YES;

            if (foundForgeToml) {
                // crude: try to find the textual mods.toml content in the jar bytes by searching for "mods.toml" and then extracting likely toml snippet
                // Better approach: use a zip library to read META-INF/mods.toml; this is a heuristic fallback.
                // Attempt to find substring "mods.toml" and then locate nearby lines with keys
                // For safety, search full jar text for presence of '[[mods]]' then parse block
                if ([jarText rangeOfString:@"[[mods]]"].location != NSNotFound || [jarText rangeOfString:@"[mods]"].location != NSNotFound) {
                    NSDictionary *fields = [self parseFirstModsTableFromTomlString:jarText];
                    if (fields.count > 0) {
                        // prefer displayName, fallback to name-like keys
                        NSString *dname = fields[@"displayName"] ?: fields[@"name"];
                        if (dname.length) mod.displayName = dname;
                        if (fields[@"description"]) mod.modDescription = fields[@"description"];
                        if (fields[@"version"]) mod.version = fields[@"version"];
                        if (fields[@"displayURL"]) mod.homepage = fields[@"displayURL"];
                        if (fields[@"homepage"]) mod.homepage = fields[@"homepage"];
                        if (fields[@"logoFile"]) {
                            NSString *logo = fields[@"logoFile"];
                            // Try several internal paths to extract logo:
                            NSArray *cands = @[
                                logo,
                                [NSString stringWithFormat:@"assets/%@/%@", [mod basename], logo],
                                [NSString stringWithFormat:@"assets/%@/%@", [mod basename.lowercaseString stringByReplacingOccurrencesOfString:@" " withString:@"_"], logo],
                                [logo lastPathComponent]
                            ];
                            NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                            NSString *iconsDir = [cacheDir stringByAppendingPathComponent:@"mod_icons"];
                            if (![[NSFileManager defaultManager] fileExistsAtPath:iconsDir]) {
                                [[NSFileManager defaultManager] createDirectoryAtPath:iconsDir withIntermediateDirectories:YES attributes:nil error:nil];
                            }
                            for (NSString *p in cands) {
                                NSString *dest = [iconsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", [mod.basename stringByReplacingOccurrencesOfString:@" " withString:@"_"], [p lastPathComponent]]];
                                if ([self extractPNGFromJar:mod.filePath internalPath:p destPath:dest]) {
                                    mod.iconURL = [NSURL fileURLWithPath:dest].absoluteString;
                                    mod.iconPathInJar = p;
                                    break;
                                }
                            }
                        }
                        // If file name or jar contains 'neoforge' marker, set isNeoForge
                        if ([jarText rangeOfString:@"neoforge"].location != NSNotFound || [jarText rangeOfString:@"neoforge.mods.toml"].location != NSNotFound) {
                            mod.isNeoForge = YES;
                        } else {
                            mod.isForge = YES;
                        }
                        gotLocal = YES;
                    }
                }
            }
        }

        // 3) mcmod.info (older Forge) — keep previous heuristic
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

        // If we didn't get local metadata and onlineSearchEnabled == YES, try remote first
        __block BOOL didRemote = NO;
        void (^remoteSearchBlock)(void) = ^{
            NSString *query = mod.displayName ?: [mod basename];
            // if fabric, try to extract name quickly from jarText
            if (!mod.isFabric && jarText && [jarText rangeOfString:@"fabric.mod.json"].location != NSNotFound) {
                NSRange nameRange = [jarText rangeOfString:@"\"name\"\\s*:\\s*\"" options:NSRegularExpressionSearch];
                if (nameRange.location != NSNotFound) {
                    NSUInteger start = NSMaxRange(nameRange);
                    NSUInteger pos = start;
                    NSMutableString *buf = [NSMutableString string];
                    while (pos < jarText.length) {
                        unichar c = [jarText characterAtIndex:pos++];
                        if (c == '\"') break;
                        [buf appendFormat:@"%C", c];
                    }
                    if (buf.length) query = buf;
                }
            }

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
            @try { remoteSearchBlock(); } @catch (...) {}
            if (!didRemote && !gotLocal) {
                // local fallback
                // (we already tried local above in current flow)
            }
        } else {
            // local-priority already executed above
            if (!gotLocal) {
                @try { remoteSearchBlock(); } @catch (...) {}
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(mod, nil);
        });
    });
}

#pragma mark - other methods (scan, toggle, delete)...
// existing scanModsForProfile:, existing existingModsFolderForProfile:, toggleEnableForMod:, deleteMod: implementations remain unchanged
@end