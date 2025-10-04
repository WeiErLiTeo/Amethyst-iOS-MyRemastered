//
//  ModTableViewCell.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Updated: multi-badge support, original rendering, fixed layout & hit areas.
//

#import "ModTableViewCell.h"
#import "ModItem.h"
#import "ModService.h"

@interface ModTableViewCell ()
@property (nonatomic, strong) ModItem *currentMod;
@end

@implementation ModTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        _modIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _modIconView.layer.cornerRadius = 6;
        _modIconView.clipsToBounds = YES;
        _modIconView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:_modIconView];

        _loaderBadgeView1 = [[UIImageView alloc] initWithFrame:CGRectZero];
        _loaderBadgeView1.contentMode = UIViewContentModeScaleAspectFit;
        _loaderBadgeView1.hidden = YES;
        [self.contentView addSubview:_loaderBadgeView1];

        _loaderBadgeView2 = [[UIImageView alloc] initWithFrame:CGRectZero];
        _loaderBadgeView2.contentMode = UIViewContentModeScaleAspectFit;
        _loaderBadgeView2.hidden = YES;
        [self.contentView addSubview:_loaderBadgeView2];

        _loaderBadgeView3 = [[UIImageView alloc] initWithFrame:CGRectZero];
        _loaderBadgeView3.contentMode = UIViewContentModeScaleAspectFit;
        _loaderBadgeView3.hidden = YES;
        [self.contentView addSubview:_loaderBadgeView3];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont boldSystemFontOfSize:15];
        _nameLabel.numberOfLines = 1;
        [self.contentView addSubview:_nameLabel];

        _descLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _descLabel.font = [UIFont systemFontOfSize:12];
        _descLabel.textColor = [UIColor darkGrayColor];
        _descLabel.numberOfLines = 2;
        [self.contentView addSubview:_descLabel];

        _toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _toggleButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_toggleButton addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];
        _toggleButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
        [self.contentView addSubview:_toggleButton];

        _openLinkButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _openLinkButton.tintColor = [UIColor systemBlueColor];
        _openLinkButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_openLinkButton addTarget:self action:@selector(openLinkTapped) forControlEvents:UIControlEventTouchUpInside];
        _openLinkButton.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        _openLinkButton.hidden = YES;
        _openLinkButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        _openLinkButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_openLinkButton];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        _deleteButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_deleteButton setTitle:@"删除" forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        _deleteButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
        [self.contentView addSubview:_deleteButton];

        // Set default background color
        self.contentView.backgroundColor = [UIColor systemBackgroundColor];

        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 10;
    CGFloat iconSize = 48;
    
    // Position mod icon view
    CGFloat iconX = padding;
    self.modIconView.frame = CGRectMake(iconX, padding, iconSize, iconSize);

    CGFloat x = CGRectGetMaxX(self.modIconView.frame) + 10;
    CGFloat rightButtonsWidth = 170;
    CGFloat contentWidth = self.contentView.bounds.size.width - x - padding - rightButtonsWidth;

    // badges: up to three small icons horizontally
    CGFloat badgeSize = 18;
    CGFloat badgeY = padding + 2;
    CGFloat badgeX = x;
    UIImageView *badges[3] = {self.loaderBadgeView1, self.loaderBadgeView2, self.loaderBadgeView3};
    for (int i = 0; i < 3; i++) {
        UIImageView *bv = badges[i];
        bv.frame = CGRectMake(badgeX, badgeY, badgeSize, badgeSize);
        badgeX += badgeSize + 6;
    }

    CGFloat nameX = x;
    // if first badge visible, shift nameX to after badges area for alignment
    if (!self.loaderBadgeView1.hidden) {
        // compute width used by visible badges
        CGFloat used = 0;
        for (int i = 0; i < 3; i++) {
            UIImageView *bv = badges[i];
            if (!bv.hidden) used += badgeSize + 6;
        }
        nameX += used;
    }
    self.nameLabel.frame = CGRectMake(nameX, padding, contentWidth - (nameX - x), 20);
    self.descLabel.frame = CGRectMake(x, CGRectGetMaxY(self.nameLabel.frame) + 4, contentWidth, 36);

    // buttons on right: delete | toggle | openLink
    CGFloat btnW = 60;
    CGFloat spacing = 8;
    CGFloat right = self.contentView.bounds.size.width - padding;
    self.deleteButton.frame = CGRectMake(right - btnW, 12, btnW, 28);
    right = CGRectGetMinX(self.deleteButton.frame) - spacing;
    self.toggleButton.frame = CGRectMake(right - btnW, 12, btnW, 28);
    right = CGRectGetMinX(self.toggleButton.frame) - spacing;
    CGFloat openW = 44;
    self.openLinkButton.frame = CGRectMake(right - openW, 12, openW, 28);

    // Bring interactive controls to front
    [self.contentView bringSubviewToFront:self.deleteButton];
    [self.contentView bringSubviewToFront:self.toggleButton];
    [self.contentView bringSubviewToFront:self.openLinkButton];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.modIconView.image = nil;
    self.loaderBadgeView1.image = nil; self.loaderBadgeView1.hidden = YES;
    self.loaderBadgeView2.image = nil; self.loaderBadgeView2.hidden = YES;
    self.loaderBadgeView3.image = nil; self.loaderBadgeView3.hidden = YES;
    self.openLinkButton.hidden = YES;
    [self.openLinkButton setImage:nil forState:UIControlStateNormal];
    self.nameLabel.attributedText = nil;
    self.nameLabel.text = nil;
    self.descLabel.text = nil;
    self.currentMod = nil;
    
    // Reset batch mode state and clear borders
    self.isBatchMode = NO;
    self.isSelectedForBatch = NO;
    
    // Clear any existing borders from previous state
    self.layer.borderColor = [UIColor clearColor].CGColor;
    self.layer.borderWidth = 0.0;
    self.layer.cornerRadius = 0.0;
    self.contentView.layer.borderColor = [UIColor clearColor].CGColor;
    self.contentView.layer.borderWidth = 0.0;
    self.contentView.layer.cornerRadius = 0.0;
    self.modIconView.layer.borderWidth = 0;
    self.selectedBackgroundView = nil;
    
    // 确保按钮在重用时可见
    self.toggleButton.hidden = NO;
    self.deleteButton.hidden = NO;
    
    // 重置contentView的frame
    self.contentView.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.height);
}

- (void)configureWithMod:(ModItem *)mod {
    self.currentMod = mod;

    // Border display logic is now handled exclusively in updateBatchSelectionState:
    // This ensures consistent behavior and avoids conflicts during cell reuse

    // name + version
    NSString *name = mod.displayName ?: mod.fileName;
    NSString *version = mod.version ?: @"";
    if (version.length > 0) {
        NSMutableAttributedString *att = [[NSMutableAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:15], NSForegroundColorAttributeName: [UIColor labelColor]}];
        NSAttributedString *verAttr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", version] attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13], NSForegroundColorAttributeName: [UIColor systemGrayColor]}];
        [att appendAttributedString:verAttr];
        self.nameLabel.attributedText = att;
    } else {
        self.nameLabel.text = name;
    }

    // description
    self.descLabel.text = mod.modDescription ?: @"";

    // toggle text
    NSString *toggleTitle = mod.disabled ? @"启用" : @"禁用";
    [self.toggleButton setTitle:toggleTitle forState:UIControlStateNormal];

    // mod icon (as before)
    UIImage *placeholder = [UIImage systemImageNamed:@"cube.box"];
    self.modIconView.image = placeholder;
    if (mod.iconURL.length > 0) {
        NSString *cachePath = [[ModService sharedService] iconCachePathForURL:mod.iconURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
            NSData *d = [NSData dataWithContentsOfFile:cachePath];
            UIImage *img = [UIImage imageWithData:d];
            if (img) self.modIconView.image = img;
        } else {
            NSURL *url = [NSURL URLWithString:mod.iconURL];
            if (url) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    NSData *d = [NSData dataWithContentsOfURL:url];
                    if (d) {
                        [d writeToFile:cachePath atomically:YES];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIImage *img = [UIImage imageWithData:d];
                            if (img) self.modIconView.image = img;
                        });
                    }
                });
            }
        }
    }

    // loader badges: try to show up to three icons: Fabric, Forge, NeoForge (in that order)
    NSArray<UIImage *> *badgeImgs = [self loaderIconsForMod:mod traitCollection:self.traitCollection];
    // assign to available badge views
    NSArray<UIImageView *> *badgeViews = @[self.loaderBadgeView1, self.loaderBadgeView2, self.loaderBadgeView3];
    for (NSUInteger i = 0; i < badgeViews.count; i++) {
        UIImageView *bv = badgeViews[i];
        if (i < badgeImgs.count && badgeImgs[i]) {
            UIImage *orig = [badgeImgs[i] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            bv.image = orig;
            bv.hidden = NO;
        } else {
            bv.image = nil;
            bv.hidden = YES;
        }
    }

    // open link button
    if (mod.homepage.length > 0 || mod.sources.length > 0) {
        self.openLinkButton.hidden = NO;
        UIImage *globe = [UIImage systemImageNamed:@"globe"];
        if (globe) {
            // 设置地球图标为蓝色
            globe = [globe imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.openLinkButton setImage:globe forState:UIControlStateNormal];
            [self.openLinkButton setTintColor:[UIColor systemBlueColor]];
            [self.openLinkButton setTitle:@"" forState:UIControlStateNormal];
        } else {
            [self.openLinkButton setTitle:@"🌐" forState:UIControlStateNormal];
        }
        self.openLinkButton.userInteractionEnabled = YES;
    } else {
        self.openLinkButton.hidden = YES;
    }
    
    // 根据mod是否被禁用来设置图标和名称的样式
    if (mod.disabled) {
        // 图标变灰 (增加虚化强度)
        self.modIconView.alpha = 0.3;
        
        // 名称变灰并划掉 (不包括版本号)
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.nameLabel.attributedText ?: [[NSAttributedString alloc] initWithString:self.nameLabel.text ?: @""]];
        // 只对名称部分应用样式，版本号部分保持不变
        NSString *name = mod.displayName ?: mod.fileName;
        NSRange nameRange = [attributedString.string rangeOfString:name];
        if (nameRange.location != NSNotFound) {
            [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:nameRange];
            [attributedString addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:nameRange];
        }
        self.nameLabel.attributedText = attributedString;
    } else {
        // 恢复图标正常状态
        self.modIconView.alpha = 1.0;
        
        // 恢复名称正常状态
        if (self.nameLabel.attributedText) {
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.nameLabel.attributedText];
            [attributedString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, attributedString.length)];
            [attributedString removeAttribute:NSStrikethroughStyleAttributeName range:NSMakeRange(0, attributedString.length)];
            self.nameLabel.attributedText = attributedString;
        } else {
            self.nameLabel.textColor = [UIColor labelColor];
        }
    }
    
    // 检查更新状态并更新UI
    if (mod.updateAvailable) {
        // 如果有更新，添加一个更新指示器
        self.nameLabel.attributedText = [self attributedStringWithUpdateIndicator:self.nameLabel.attributedText ?: [[NSAttributedString alloc] initWithString:self.nameLabel.text ?: @""]];
    }
    
    // 显示加载状态
    if (!mod.metadataLoaded) {
        // 如果元数据未加载，在描述中显示"加载中..."的提示
        self.descLabel.text = @"加载中...";
        self.descLabel.textColor = [UIColor systemGrayColor];
    } else {
        // 元数据已加载，恢复正常的描述显示
        self.descLabel.text = mod.modDescription ?: @"";
        self.descLabel.textColor = [UIColor darkGrayColor];
    }
}

// 添加更新指示器到 NSAttributedString
- (NSAttributedString *)attributedStringWithUpdateIndicator:(NSAttributedString *)originalString {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:originalString];
    
    // 添加更新指示器 (一个明显的更新标记)
    NSString *indicator = @" [有更新]";
    NSMutableAttributedString *indicatorString = [[NSMutableAttributedString alloc] initWithString:indicator];
    [indicatorString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0, indicator.length)];
    [indicatorString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:12] range:NSMakeRange(0, indicator.length)];
    
    [attributedString appendAttributedString:indicatorString];
    
    return attributedString;
}

- (NSArray<UIImage *> *)loaderIconsForMod:(ModItem *)mod traitCollection:(UITraitCollection *)traits {
    if (!mod) return @[];

    NSMutableArray<UIImage *> *out = [NSMutableArray array];

    // Helper to load image by base name (fabric/forge/neoforge)
    __weak typeof(self) wself = self;
    UIImage *(^loadImage)(NSString *) = ^UIImage *(NSString *base) {
        if (!base) return nil;
        NSString *suffix = @"light";
        if (@available(iOS 12.0, *)) {
            if (traits) suffix = (traits.userInterfaceStyle == UIUserInterfaceStyleDark) ? @"dark" : @"light";
            else suffix = ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? @"dark":@"light";
        }
        NSString *resourceName = [NSString stringWithFormat:@"%@_%@", base, suffix];
        UIImage *img = nil;
        NSArray<NSString *> *resourceDirCandidates = @[@"ModLoaderIcons", @"Natives/ModLoaderIcons", @"Natives/ModLoaderIcons/Resources"];
        for (NSString *dir in resourceDirCandidates) {
            NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:dir];
            filePath = [filePath stringByAppendingPathComponent:[resourceName stringByAppendingPathExtension:@"png"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                img = [UIImage imageWithContentsOfFile:filePath];
                if (img) break;
            }
        }
        if (!img) {
            NSString *fileInBundle = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png"];
            if (fileInBundle) img = [UIImage imageWithContentsOfFile:fileInBundle];
        }
        if (!img) img = [UIImage imageNamed:resourceName];
        return img;
    };

    // Always try to add in order Fabric, Forge, NeoForge if the mod supports them
    if (mod.isFabric) {
        UIImage *i = loadImage(@"fabric");
        if (i) [out addObject:i];
    }
    if (mod.isForge) {
        UIImage *i = loadImage(@"forge");
        if (i) [out addObject:i];
    }
    if (mod.isNeoForge) {
        UIImage *i = loadImage(@"neoforge");
        if (i) [out addObject:i];
    }

    return out;
}

#pragma mark - Public Methods

- (void)updateToggleState:(BOOL)disabled {
    NSString *toggleTitle = disabled ? @"启用" : @"禁用";
    [self.toggleButton setTitle:toggleTitle forState:UIControlStateNormal];
    
    // 更新图标和名称的样式
    if (disabled) {
        // 图标变灰 (增加虚化强度)
        self.modIconView.alpha = 0.3;
        
        // 名称变灰并划掉 (不包括版本号)
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.nameLabel.attributedText ?: [[NSAttributedString alloc] initWithString:self.nameLabel.text ?: @""]];
        // 只对名称部分应用样式，版本号部分保持不变
        if (self.currentMod) {
            NSString *name = self.currentMod.displayName ?: self.currentMod.fileName;
            NSRange nameRange = [attributedString.string rangeOfString:name];
            if (nameRange.location != NSNotFound) {
                [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:nameRange];
                [attributedString addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:nameRange];
            }
        }
        self.nameLabel.attributedText = attributedString;
    } else {
        // 恢复图标正常状态
        self.modIconView.alpha = 1.0;
        
        // 恢复名称正常状态
        if (self.nameLabel.attributedText) {
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.nameLabel.attributedText];
            [attributedString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, attributedString.length)];
            [attributedString removeAttribute:NSStrikethroughStyleAttributeName range:NSMakeRange(0, attributedString.length)];
            self.nameLabel.attributedText = attributedString;
        } else {
            self.nameLabel.textColor = [UIColor labelColor];
        }
    }
    
    // 检查更新状态并更新UI
    if (self.currentMod && self.currentMod.updateAvailable) {
        self.nameLabel.attributedText = [self attributedStringWithUpdateIndicator:self.nameLabel.attributedText ?: [[NSAttributedString alloc] initWithString:self.nameLabel.text ?: @""]];
    }
}

- (void)updateBatchSelectionState:(BOOL)isSelected batchMode:(BOOL)batchMode {
    // Only update if the state has changed
    if (self.isSelectedForBatch == isSelected && self.isBatchMode == batchMode) {
        return;
    }
    
    self.isSelectedForBatch = isSelected;
    self.isBatchMode = batchMode;
    
    // Update selection border for batch mode (3px green border with 2px inset, iOS 14+ compatible)
    if (batchMode && isSelected) {
        self.layer.borderColor = [UIColor greenColor].CGColor;
        self.layer.borderWidth = 3.0;
        self.layer.cornerRadius = 6.0;
        self.layer.masksToBounds = YES;
        self.contentView.layer.masksToBounds = YES;
        self.selectedBackgroundView = nil;
        
        // Add a 2px inset by adjusting the frame
        self.contentView.frame = CGRectMake(2.0, 2.0, self.bounds.size.width - 4.0, self.bounds.size.height - 4.0);
        
        // 在批量模式下禁用所有按钮而不是隐藏
        self.toggleButton.enabled = NO;
        self.toggleButton.alpha = 0.5;  // 添加虚化效果
        self.deleteButton.enabled = NO;
        self.deleteButton.alpha = 0.5;  // 添加虚化效果
        self.openLinkButton.enabled = NO;
        self.openLinkButton.alpha = 0.5;  // 添加虚化效果
    } else {
        self.layer.borderColor = [UIColor clearColor].CGColor;
        self.layer.borderWidth = 0.0;
        self.layer.cornerRadius = 0.0;
        self.selectedBackgroundView = nil;
        
        // Reset the frame
        self.contentView.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.height);
        
        // 退出批量模式时启用所有按钮并恢复透明度
        self.toggleButton.enabled = YES;
        self.toggleButton.alpha = 1.0;
        self.deleteButton.enabled = YES;
        self.deleteButton.alpha = 1.0;
        self.openLinkButton.enabled = YES;
        self.openLinkButton.alpha = 1.0;
    }

    // Update icon view border to indicate selection
    if (batchMode && isSelected) {
        self.modIconView.layer.borderWidth = 3.0;
        self.modIconView.layer.borderColor = [UIColor whiteColor].CGColor;
    } else {
        self.modIconView.layer.borderWidth = 0;
    }
}

#pragma mark - Actions

- (void)toggleTapped {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapToggle:)]) {
        [self.delegate modCellDidTapToggle:self];
    }
}

- (void)deleteTapped {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapDelete:)]) {
        [self.delegate modCellDidTapDelete:self];
    }
}

- (void)openLinkTapped {
    // 在批量模式下不执行跳转操作
    if (self.isBatchMode) {
        return;
    }
    
    if (!self.currentMod) return;
    if (!(self.currentMod.homepage.length || self.currentMod.sources.length)) return;
    if ([self.delegate respondsToSelector:@selector(modCellDidTapOpenLink:)]) {
        [self.delegate modCellDidTapOpenLink:self];
    }
}

// Removed iconTapped: method to avoid conflicts with table view selection

@end