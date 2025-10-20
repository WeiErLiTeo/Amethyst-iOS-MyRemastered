#import "ModVersion.h"

@implementation ModVersion

// Helper to get a configured date formatter
+ (NSISO8601DateFormatter *)dateFormatter {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });
    return formatter;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        @try {
            if (![dictionary isKindOfClass:[NSDictionary class]]) {
                return nil;
            }

            _name = [dictionary[@"name"] isKindOfClass:[NSString class]] ? dictionary[@"name"] : @"Unknown Name";
            _versionNumber = [dictionary[@"version_number"] isKindOfClass:[NSString class]] ? dictionary[@"version_number"] : @"Unknown Version";

            id dateString = dictionary[@"date_published"];
            if (dateString && [dateString isKindOfClass:[NSString class]]) {
                _datePublished = [[self.class dateFormatter] dateFromString:dateString];
            }
            if (!_datePublished) {
                _datePublished = [NSDate distantPast]; // Fallback
            }

            _gameVersions = [dictionary[@"game_versions"] isKindOfClass:[NSArray class]] ? dictionary[@"game_versions"] : @[];
            _loaders = [dictionary[@"loaders"] isKindOfClass:[NSArray class]] ? dictionary[@"loaders"] : @[];

            NSArray *files = [dictionary[@"files"] isKindOfClass:[NSArray class]] ? dictionary[@"files"] : @[];
            // Find the primary file, fallback to the first file if none are marked primary
            _primaryFile = nil;
            for (NSDictionary *file in files) {
                if ([file isKindOfClass:[NSDictionary class]] && [file[@"primary"] boolValue]) {
                    _primaryFile = file;
                    break;
                }
            }
            if (!_primaryFile && files.count > 0) {
                _primaryFile = files.firstObject;
            }

        } @catch (NSException *exception) {
            NSLog(@"[ModVersion] Failed to initialize from dictionary. Reason: %@, Dict: %@", exception.reason, dictionary);
            return nil; // Failed initialization
        }
    }
    return self;
}

@end
