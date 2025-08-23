//
//  ModItem.h
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import <Foundation/Foundation.h>

@interface ModItem : NSObject

@property (nonatomic, copy) NSString *filePath;      // full path to jar
@property (nonatomic, copy) NSString *fileName;      // file name
@property (nonatomic, copy) NSString *displayName;   // friendly display name (from metadata or filename)
@property (nonatomic, copy) NSString *modDescription;// description/summary
@property (nonatomic, copy) NSString *fileSHA1;      // computed sha1 of file (optional)
@property (nonatomic, copy) NSString *iconURL;       // network URL or file:// URL pointing to cached icon
@property (nonatomic, copy) NSString *iconPathInJar; // internal path inside jar if known (e.g. assets/.../icon.png)
@property (nonatomic, copy) NSString *homepage;      // homepage or project url
@property (nonatomic, copy) NSString *sources;       // sources url if present
@property (nonatomic, copy) NSString *version;       // version string from metadata

@property (nonatomic, assign) BOOL disabled;         // whether file is "disabled" (filename contains .disabled)
@property (nonatomic, assign) BOOL isFabric;         // detected fabric mod
@property (nonatomic, assign) BOOL isForge;          // detected forge mod (mods.toml)
@property (nonatomic, assign) BOOL isNeoForge;       // detected neoforge mod (neoforge.mods.toml)

- (instancetype)initWithFilePath:(NSString *)path;

// basename: file name without .disabled / .jar suffixes
- (NSString *)basename;

// refresh disabled flag from filename
- (void)refreshDisabledFlag;

@end