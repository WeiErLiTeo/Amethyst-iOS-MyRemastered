#import "ModItem.h"

@implementation ModItem

- (instancetype)initWithFilePath:(NSString *)path {
    if (self = [super init]) {
        _filePath = [path copy];
        _fileName = [[path lastPathComponent] copy];
        [self refreshDisabledFlag];
        NSString *name = [_fileName copy];

        if ([name hasSuffix:@".disabled"]) {
            name = [name substringToIndex:name.length - [@".disabled" length]];
        }
        if ([name hasSuffix:@".jar"]) {
            name = [name stringByDeletingPathExtension];
        }
        _displayName = name.length ? name : _fileName;
    }
    return self;
}

- (instancetype)initWithOnlineData:(NSDictionary *)data {
    if (self = [super init]) {
        // Data from Modrinth search results. Prioritize 'slug' for URLs.
        _onlineID = data[@"slug"] ?: (data[@"project_id"] ? [data[@"project_id"] description] : nil);
        _displayName = data[@"title"] ?: @"";
        // The short description in search results is 'summary'. 'description' is the full markdown body.
        _modDescription = data[@"summary"] ?: (data[@"description"] ?: @"");
        _iconURL = data[@"icon_url"] ?: @"";
        _author = data[@"author"] ?: @"";

        // Ensure numbers are handled correctly
        id downloadsValue = data[@"downloads"];
        if ([downloadsValue isKindOfClass:[NSNumber class]]) {
            _downloads = downloadsValue;
        } else if ([downloadsValue respondsToSelector:@selector(longLongValue)]) {
            _downloads = @([downloadsValue longLongValue]);
        }

        id likesValue = data[@"likes"];
        if ([likesValue isKindOfClass:[NSNumber class]]) {
            _likes = likesValue;
        } else if ([likesValue respondsToSelector:@selector(longLongValue)]) {
            _likes = @([likesValue longLongValue]);
        }

        // Handle dates and categories
        _lastUpdated = data[@"lastUpdated"] ?: @"";
        _categories = data[@"categories"] ?: @[];

        // These will be nil until a version is selected for download
        _filePath = nil;
        _fileName = nil;
    }
    return self;
}

- (void)refreshDisabledFlag {
    _disabled = [_fileName.lowercaseString hasSuffix:@".disabled"];
}

- (NSString *)basename {
    NSString *name = _fileName ?: @"";
    if ([name hasSuffix:@".disabled"]) {
        name = [name substringToIndex:name.length - [@".disabled" length]];
    }
    if ([name hasSuffix:@".jar"]) name = [name stringByDeletingPathExtension];
    return name;
}

@end
