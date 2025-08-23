//
//  ModTableViewCell.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import "ModTableViewCell.h"
#import "UIKit+AFNetworking.h"
#import "ModItem.h"

@interface ModTableViewCell ()
@property (nonatomic, strong) UIImageView *modIconView;
@property (nonatomic, strong) UIImageView *fabricBadgeView; // small fabric icon before name
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *versionLabel; // small grey version text
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *linkButton; // globe link
@property (nonatomic, strong) ModItem *currentMod;
@end

@implementation ModTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.modIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.modIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.modIconView.clipsToBounds = YES;
    self.modIconView.layer.cornerRadius = 6.0;
    [self.contentView addSubview:self.modIconView];

    // fabric badge (small image same line as title)
    self.fabricBadgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.fabricBadgeView.contentMode = UIViewContentModeScaleAspectFit;
    self.fabricBadgeView.hidden = YES;
    [self.contentView addSubview:self.fabricBadgeView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.contentView addSubview:self.titleLabel];

    self.versionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.versionLabel.font = [UIFont systemFontOfSize:12];
    self.versionLabel.textColor = [UIColor systemGrayColor];
    [self.contentView addSubview:self.versionLabel];

    self.descLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.descLabel.font = [UIFont systemFontOfSize:12];
    self.descLabel.textColor = [UIColor systemGrayColor];
    self.descLabel.numberOfLines = 2;
    [self.contentView addSubview:self.descLabel];

    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.toggleButton setTitle:@"切换" forState:UIControlStateNormal];
    [self.toggleButton addTarget:self action:@selector(actionToggle:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.toggleButton];

    self.deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.deleteButton setTitle:@"删除" forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [self.deleteButton addTarget:self action:@selector(actionDelete:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.deleteButton];

    self.linkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.linkButton setTitle:@"🌐" forState:UIControlStateNormal];
    self.linkButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.linkButton addTarget:self action:@selector(actionOpenLink:) forControlEvents:UIControlEventTouchUpInside];
    self.linkButton.hidden = YES;
    [self.contentView addSubview:self.linkButton];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 10;
    CGFloat iconSize = 56;
    self.modIconView.frame = CGRectMake(padding, (self.contentView.bounds.size.height - iconSize)/2, iconSize, iconSize);

    CGFloat left = CGRectGetMaxX(self.modIconView.frame) + 12;
    CGFloat right = self.contentView.bounds.size.width - padding;
    CGFloat buttonWidth = 56;

    // Title row: optional fabric badge + title + version
    CGFloat titleHeight = 20;
    CGFloat badgeSize = 16;
    CGFloat badgeLeft = left;
    if (!self.fabricBadgeView.hidden) {
        self.fabricBadgeView.frame = CGRectMake(badgeLeft, padding + (titleHeight - badgeSize)/2, badgeSize, badgeSize);
        self.titleLabel.frame = CGRectMake(CGRectGetMaxX(self.fabricBadgeView.frame) + 6, padding, right - left - buttonWidth*2 - 8 - badgeSize, titleHeight);
    } else {
        self.fabricBadgeView.frame = CGRectZero;
        self.titleLabel.frame = CGRectMake(left, padding, right - left - buttonWidth*2 - 8, titleHeight);
    }

    // version label placed right after title
    CGSize verSize = [self.versionLabel sizeThatFits:CGSizeMake(120, 20)];
    self.versionLabel.frame = CGRectMake(CGRectGetMaxX(self.titleLabel.frame) + 6, padding + 2, verSize.width, verSize.height);

    self.descLabel.frame = CGRectMake(left, CGRectGetMaxY(self.titleLabel.frame) + 4, right - left - buttonWidth*2 - 8, 36);

    // Buttons: right side: delete, toggle, link (from right to left)
    CGFloat btnW = 56;
    self.deleteButton.frame = CGRectMake(right - btnW, (self.contentView.bounds.size.height - 30)/2, btnW, 30);
    self.toggleButton.frame = CGRectMake(right - btnW*2 - 6, (self.contentView.bounds.size.height - 30)/2, btnW, 30);
    self.linkButton.frame = CGRectMake(right - btnW*3 - 12, (self.contentView.bounds.size.height - 30)/2, 34, 30);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.modIconView.image = nil;
    self.fabricBadgeView.image = nil;
    self.fabricBadgeView.hidden = YES;
    self.titleLabel.text = nil;
    self.versionLabel.text = nil;
    self.descLabel.text = nil;
    self.currentMod = nil;
    self.linkButton.hidden = YES;
}

static UIImage *resizeImageToSize(UIImage *image, CGSize size) {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized ?: image;
}

- (void)configureWithMod:(ModItem *)mod {
    self.currentMod = mod;

    // Title and version
    self.titleLabel.text = mod.displayName ?: [mod basename];
    if (mod.version.length) {
        self.versionLabel.text = [NSString stringWithFormat:@"%@", mod.version];
    } else {
        self.versionLabel.text = @"";
    }

    // Description
    self.descLabel.text = mod.modDescription ?: mod.fileName;

    // Placeholder
    UIImage *placeholder = [UIImage imageNamed:@"DefaultModIcon"];
    if (placeholder) placeholder = resizeImageToSize(placeholder, CGSizeMake(56, 56));

    // If we have a local file URL (file://...), set it; AFNetworking also accepts file URLs
    if (mod.iconURL.length) {
        NSURL *iconURL = [NSURL URLWithString:mod.iconURL];
        if ([iconURL.scheme.lowercaseString isEqualToString:@"file"]) {
            NSData *imgData = [NSData dataWithContentsOfURL:iconURL];
            if (imgData) {
                UIImage *img = [UIImage imageWithData:imgData];
                if (img) {
                    self.modIconView.image = resizeImageToSize(img, CGSizeMake(56,56));
                } else {
                    self.modIconView.image = placeholder;
                }
            } else {
                self.modIconView.image = placeholder;
            }
        } else {
            // network url
            [self.modIconView setImageWithURL:[NSURL URLWithString:mod.iconURL] placeholderImage:placeholder];
        }
    } else {
        self.modIconView.image = placeholder;
    }

    // Fabric badge
    if (mod.isFabric) {
        // try to use a bundled Fabric badge asset if available, otherwise a simple colored square
        UIImage *badge = [UIImage imageNamed:@"FabricBadgeIcon"];
        if (!badge) {
            // create a small blue square as fallback
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(16,16), NO, 0.0);
            [[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0] setFill];
            UIRectFill(CGRectMake(0,0,16,16));
            badge = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        self.fabricBadgeView.image = badge;
        self.fabricBadgeView.hidden = NO;
    } else {
        self.fabricBadgeView.hidden = YES;
    }

    // Link button: show if homepage/sources present
    NSString *link = mod.homepage ?: mod.sources;
    self.linkButton.hidden = (link.length == 0);
    // toggle button text
    NSString *toggleTitle = mod.disabled ? @"启用" : @"禁用";
    [self.toggleButton setTitle:toggleTitle forState:UIControlStateNormal];
}

#pragma mark - Actions

- (void)actionToggle:(id)sender {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapToggle:)]) {
        [self.delegate modCellDidTapToggle:self];
    }
}

- (void)actionDelete:(id)sender {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapDelete:)]) {
        [self.delegate modCellDidTapDelete:self];
    }
}

- (void)actionOpenLink:(id)sender {
    if (!self.currentMod) return;
    NSString *urlStr = self.currentMod.homepage ?: self.currentMod.sources;
    if (!urlStr) return;
    NSURL *u = [NSURL URLWithString:urlStr];
    if (!u) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:u];
        }
    });
}

@end