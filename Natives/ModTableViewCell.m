//
//  ModTableViewCell.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Updated to fix open-link hit area, ensure loader badge loads from bundle (Natives/ModLoaderIcons fallback),
//  and ensure buttons are on top so touches are registered.
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
        _loaderBadgeView.userInteractionEnabled = NO; // decorative
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
        _toggleButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
        [self.contentView addSubview:_toggleButton];

        _openLinkButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _openLinkButton.tintColor = [UIColor systemBlueColor];
        _openLinkButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_openLinkButton addTarget:self action:@selector(openLinkTapped) forControlEvents:UIControlEventTouchUpInside];
        // make hit area comfortably large
        _openLinkButton.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        _openLinkButton.hidden = YES;
        [self.contentView addSubview:_openLinkButton];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        _deleteButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_deleteButton setTitle:@"删除" forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        _deleteButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
        [self.contentView addSubview:_deleteButton];

        // Improve tap behavior: ensure accessory views don't block touches
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 10;
    CGFloat iconSize = 48;
    self.modIconView.frame = CGRectMake(padding, padding, iconSize, iconSize);

    CGFloat x = CGRectGetMaxX(self.modIconView.frame) + 10;
    CGFloat rightButtonsWidth = 160; // space for buttons
    CGFloat contentWidth = self.contentView.bounds.size.width - x - padding - rightButtonsWidth;

    // badge size (fits visually with name)
    CGFloat badgeSize = 18;
    CGFloat badgeY = padding + 2;
    self.loaderBadgeView.frame = CGRectMake(x, badgeY, badgeSize, badgeSize);

    // name label placed after badge when visible
    CGFloat nameX = x;
    if (!self.loaderBadgeView.hidden) {
        nameX += badgeSize + 6;
    }
    self.nameLabel.frame = CGRectMake(nameX, padding, contentWidth - (nameX - x), 20);
    self.descLabel.frame = CGRectMake(x, CGRectGetMaxY(self.nameLabel.frame) + 4, contentWidth, 36);

    // buttons on right: delete | toggle | openLink (openLink leftmost)
    CGFloat btnW = 60;
    CGFloat spacing = 8;
    CGFloat right = self.contentView.bounds.size.width - padding;
    self.deleteButton.frame = CGRectMake(right - btnW, 12, btnW, 28);
    right = CGRectGetMinX(self.deleteButton.frame) - spacing;
    self.toggleButton.frame = CGRectMake(right - btnW, 12, btnW, 28);
    right = CGRectGetMinX(self.toggleButton.frame) - spacing;
    self.openLinkButton.frame = CGRectMake(right - btnW, 12, btnW, 28);

    // Ensure interactive controls are on top
    [self.contentView bringSubviewToFront:self.deleteButton];
    [self.contentView bringSubviewToFront:self.toggleButton];
    [self.contentView bringSubviewToFront:self.openLinkButton];
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

    // loader badge: choose appropriate icon from bundle (check several resource directories)
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

    UIImage *img = nil;

    // 1) Try to find under bundled "ModLoaderIcons" directory (this covers Natives/ModLoaderIcons packaged as resources)
    NSString *resourceDirCandidates[] = {@"ModLoaderIcons", @"Natives/ModLoaderIcons", @"Natives/ModLoaderIcons/Resources", nil};
    for (int i = 0; resourceDirCandidates[i] != nil && !img; i++) {
        NSString *dir = resourceDirCandidates[i];
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:dir];
        NSString *filePath = [path stringByAppendingPathComponent:[resourceName stringByAppendingPathExtension:@"png"]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            img = [UIImage imageWithContentsOfFile:filePath];
            break;
        }
    }

    // 2) Fallback to resource named (assets or imageNamed)
    if (!img) {
        NSString *fileInBundle = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png"];
        if (fileInBundle) img = [UIImage imageWithContentsOfFile:fileInBundle];
    }
    if (!img) {
        img = [UIImage imageNamed:resourceName]; // final fallback if asset catalog used
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
    // Defensive: ensure we have a current mod and it actually has a link
    if (!self.currentMod) return;
    if (!(self.currentMod.homepage.length || self.currentMod.sources.length)) return;
    if ([self.delegate respondsToSelector:@selector(modCellDidTapOpenLink:)]) {
        [self.delegate modCellDidTapOpenLink:self];
    }
}

@end