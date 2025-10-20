#import "ModVersion.h"

@implementation ModVersion

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        if (![dictionary isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        _name = [dictionary[@"name"] isKindOfClass:[NSString class]] ? dictionary[@"name"] : @"Unknown Name";
        _versionNumber = [dictionary[@"version_number"] isKindOfClass:[NSString class]] ? dictionary[@"version_number"] : @"Unknown Version";

        // Robust date parsing
        NSString *dateString = dictionary[@"date_published"];
        if ([dateString isKindOfClass:[NSString class]] && dateString.length > 0) {
            NSISO8601DateFormatter *isoFormatter = [[NSISO8601DateFormatter alloc] init];
            isoFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;

            NSDate *date = [isoFormatter dateFromString:dateString];
            if (date) {
                NSDateFormatter *displayFormatter = [[NSDateFormatter alloc] init];
                displayFormatter.dateStyle = NSDateFormatterShortStyle;
                displayFormatter.timeStyle = NSDateFormatterNoStyle;
                _datePublished = [displayFormatter stringFromDate:date];
            } else {
                _datePublished = @"未知日期";
            }
        } else {
            _datePublished = @"未知日期";
        }

        _gameVersions = [dictionary[@"game_versions"] isKindOfClass:[NSArray class]] ? dictionary[@"game_versions"] : @[];
        _loaders = [dictionary[@"loaders"] isKindOfClass:[NSArray class]] ? dictionary[@"loaders"] : @[];

        NSArray *files = [dictionary[@"files"] isKindOfClass:[NSArray class]] ? dictionary[@"files"] : @[];
        _primaryFile = [files firstObject];
    }
    return self;
}

@end
