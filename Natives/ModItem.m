//
//  ModItem.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import "ModItem.h"

@implementation ModItem

- (instancetype)initWithFilePath:(NSString *)path {
    self = [super init];
    if (!self) return nil;
    _filePath = [path copy];
    _fileName = [_filePath lastPathComponent];
    [self refreshDisabledFlag];

    // Derive a friendly display name from filename
    NSString *name = _fileName;
    // Remove known suffixes
    name = [name stringByReplacingOccurrencesOfString:@".jar.disabled" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@".jar" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@".disabled" withString:@""];
    // Replace underscores with spaces and remove file extension remnants
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];

    // Try to strip trailing version-like tokens (basic heuristic)
    NSArray<NSString *> *parts = [name componentsSeparatedByString:@"-"];
    if (parts.count > 1) {
        // If last part contains digits, drop it
        NSString *last = parts.lastObject;
        NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
        BOOL hasDigit = ([last rangeOfCharacterFromSet:digits].location != NSNotFound);
        if (hasDigit) {
            parts = [parts subarrayWithRange:NSMakeRange(0, parts.count-1)];
            name = [parts componentsJoinedByString:@"-"];
        }
    }

    // Trim
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _displayName = name.length ? name : _fileName;

    // defaults
    _modDescription = nil;
    _fileSHA1 = nil;
    _iconURL = nil;
    _iconPathInJar = nil;
    _homepage = nil;
    _sources = nil;
    _version = nil;
    _isFabric = NO;
    _isForge = NO;
    _isNeoForge = NO;

    return self;
}

- (NSString *)basename {
    NSString *n = self.fileName;
    n = [n stringByReplacingOccurrencesOfString:@".jar.disabled" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@".jar" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@".disabled" withString:@""];
    return n;
}

- (void)refreshDisabledFlag {
    NSString *fn = self.fileName.lowercaseString;
    _disabled = ([fn containsString:@".disabled"] || [fn hasSuffix:@".disabled"] || [fn hasSuffix:@".jar.disabled"]);
}

@end