//
//  ModTableViewCell.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Updated to show Fabric/Forge/NeoForge loader badges (ModLoaderIcons) and external link (homepage/sources).
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

        _loaderBadgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _loaderBadgeView.contentMode = UIViewContentModeScaleAspectFit;
        _loaderBadgeView.hidden = YES;
        [self.contentView addSubview:_loaderBadgeView];

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
        [self.contentView addSubview:_toggleButton];

        _openLinkButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _openLinkButton.tintColor = [UIColor systemBlueColor];
        _openLinkButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_openLinkButton addTarget:self action:@selector(openLinkTapped) forControlEvents:UIControlEventTouchUpInside];
        _openLinkButton.hidden = YES;
        [self.contentView addSubview:_openLinkButton];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        _deleteButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_deleteButton setTitle:@"删除" forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_deleteButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 10;
    CGFloat iconSize = 48;
    self.modIconView.frame = CGRectMake(padding, padding, iconSize, iconSize);

    CGFloat x = CGRectGetMaxX(self.modIconView.frame) + 10;
    CGFloat rightButtonsWidth = 160;
    CGFloat contentWidth = self.contentView.bounds.size.width - x - padding - rightButtonsWidth;

    // badge size
    CGFloat badgeSize = 18;
    CGFloat badgeY = padding + 2;
    self.loaderBadgeView.frame = CGRectMake(x, badgeY, badgeSize, badgeSize);

    // name label position: if badge visible, name placed after badge
    CGFloat nameX = x;
    if (!self.loaderBadgeView.hidden) {
        nameX += badgeSize + 6;
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
    self.openLinkButton.frame = CGRectMake(right - btnW, 12, btnW, 28);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.modIconView.image = nil;
    self.loaderBadgeView.image = nil;
    self.loaderBadgeView.hidden = YES;
    self.openLinkButton.hidden = YES;
    self.nameLabel.attributedText = nil;
    self.nameLabel.text = nil;
    self.descLabel.text = nil;
    self.currentMod = nil;
}

- (void)configureWithMod:(ModItem *)mod {
    self.currentMod = mod;

    // name + version as attributed string (version smaller and gray)
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

    // icon (mod icon)
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

    // loader badge: choose appropriate icon from Natives/ModLoaderIcons
    UIImage *loaderImg = [self loaderIconForMod:mod traitCollection:self.traitCollection];
    if (loaderImg) {
        self.loaderBadgeView.image = loaderImg;
        self.loaderBadgeView.hidden = NO;
    } else {
        self.loaderBadgeView.hidden = YES;
    }

    // open link button (homepage优先, sources 次之)
    if (mod.homepage.length > 0 || mod.sources.length > 0) {
        self.openLinkButton.hidden = NO;
        UIImage *globe = [UIImage systemImageNamed:@"globe"];
        if (globe) {
            [self.openLinkButton setImage:globe forState:UIControlStateNormal];
            [self.openLinkButton setTitle:@"" forState:UIControlStateNormal];
        } else {
            [self.openLinkButton setTitle:@"🌐" forState:UIControlStateNormal];
        }
    } else {
        self.openLinkButton.hidden = YES;
    }
}

#pragma mark - Helper: load loader icon according to mod type and current interface style

- (UIImage *)loaderIconForMod:(ModItem *)mod traitCollection:(UITraitCollection *)traits {
    if (!mod) return nil;
    NSString *base = nil;
    if (mod.isFabric) base = @"fabric";
    else if (mod.isForge) base = @"forge";
    else if (mod.isNeoForge) base = @"neoforge";
    if (!base) return nil;

    // Determine dark/light
    BOOL dark = NO;
    if (@available(iOS 12.0, *)) {
        if (traits) dark = (traits.userInterfaceStyle == UIUserInterfaceStyleDark);
        else dark = ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    NSString *suffix = dark ? @"dark" : @"light";
    NSString *resourceName = [NSString stringWithFormat:@"%@_%@", base, suffix]; // e.g. fabric_dark

    // Try to load from bundle subdirectory "ModLoaderIcons"
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ModLoaderIcons"];
    UIImage *img = nil;
    if (path) {
        img = [UIImage imageWithContentsOfFile:path];
    }
    // Fallback to imageNamed (in case images are in asset catalogs or resource root)
    if (!img) {
        img = [UIImage imageNamed:resourceName];
    }
    return img;
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
    if ([self.delegate respondsToSelector:@selector(modCellDidTapOpenLink:)]) {
        [self.delegate modCellDidTapOpenLink:self];
    }
}

@end