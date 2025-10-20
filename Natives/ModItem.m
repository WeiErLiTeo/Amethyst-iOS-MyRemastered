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
        // --- Robustly extract 'onlineID' ---
        id slug = data[@"slug"];
        id projectId = data[@"project_id"];
        if (slug && [slug isKindOfClass:[NSString class]] && ((NSString *)slug).length > 0) {
            _onlineID = slug;
        } else if (projectId && [projectId respondsToSelector:@selector(description)]) {
            _onlineID = [projectId description];
        } else {
            _onlineID = @""; // Fallback to empty string
        }

        _displayName = (data[@"title"] && [data[@"title"] isKindOfClass:[NSString class]]) ? data[@"title"] : @"";

        // --- Robustly extract 'modDescription' ---
        id summary = data[@"summary"];
        id description = data[@"description"];
        if (summary && [summary isKindOfClass:[NSString class]] && ((NSString *)summary).length > 0) {
            _modDescription = summary;
        } else if (description && [description isKindOfClass:[NSString class]]) {
            _modDescription = description;
        } else {
            _modDescription = @""; // Fallback to empty string
        }

        _iconURL = (data[@"icon_url"] && [data[@"icon_url"] isKindOfClass:[NSString class]]) ? data[@"icon_url"] : @"";
        _author = (data[@"author"] && [data[@"author"] isKindOfClass:[NSString class]]) ? data[@"author"] : @"";

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
        id lastUpdatedValue = data[@"lastUpdated"];
        if (lastUpdatedValue && [lastUpdatedValue isKindOfClass:[NSString class]]) {
            _lastUpdated = lastUpdatedValue;
        } else if (lastUpdatedValue && [lastUpdatedValue isKindOfClass:[NSDate class]]) {
            // If the API ever sends a real date object, format it.
             _lastUpdated = [NSISO8601DateFormatter stringFromDate:(NSDate *)lastUpdatedValue
                                                          timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]
                                                            formatOptions:NSISO8601DateFormatWithInternetDateTime];
        }
        else {
            _lastUpdated = @""; // Fallback to empty string
        }
        _categories = (data[@"categories"] && [data[@"categories"] isKindOfClass:[NSArray class]]) ? data[@"categories"] : @[];


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
