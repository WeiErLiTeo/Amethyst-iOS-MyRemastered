#import "ModTableViewCell.h"
#import "ModItem.h"
#import "ModService.h"

@implementation ModTableViewCell

- (void)configureWithMod:(ModItem *)mod {
    self.currentMod = mod;

    // 设置占位图标
    UIImage *placeholder = [UIImage systemImageNamed:@"cube.box"];
    self.modIconView.image = placeholder;

    // 检查并加载图标
    if (mod.iconURL.length > 0) {
        NSString *cachePath = [[ModService sharedService] iconCachePathForURL:mod.iconURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
            NSData *data = [NSData dataWithContentsOfFile:cachePath];
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                self.modIconView.image = image;
            }
        } else {
            // 下载图标并缓存
            NSURL *url = [NSURL URLWithString:mod.iconURL];
            if (url) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    NSData *data = [NSData dataWithContentsOfURL:url];
                    if (data) {
                        [data writeToFile:cachePath atomically:YES];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIImage *image = [UIImage imageWithData:data];
                            if (image) {
                                self.modIconView.image = image;
                            }
                        });
                    }
                });
            }
        }
    }
}

@end