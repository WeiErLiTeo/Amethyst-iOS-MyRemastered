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
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *deleteButton;
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

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.contentView addSubview:self.titleLabel];

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

    self.titleLabel.frame = CGRectMake(left, padding, right - left - buttonWidth*2 - 8, 20);
    self.descLabel.frame = CGRectMake(left, CGRectGetMaxY(self.titleLabel.frame) + 4, right - left - buttonWidth*2 - 8, 36);

    self.deleteButton.frame = CGRectMake(right - buttonWidth, (self.contentView.bounds.size.height - 30)/2, buttonWidth, 30);
    self.toggleButton.frame = CGRectMake(right - buttonWidth*2 - 6, (self.contentView.bounds.size.height - 30)/2, buttonWidth, 30);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.modIconView.image = nil;
    self.titleLabel.text = nil;
    self.descLabel.text = nil;
    self.currentMod = nil;
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
    self.titleLabel.text = mod.displayName ?: [mod basename];
    self.descLabel.text = mod.modDescription ?: mod.fileName;

    UIImage *placeholder = [UIImage imageNamed:@"DefaultModIcon"];
    if (placeholder) {
        placeholder = resizeImageToSize(placeholder, CGSizeMake(56, 56));
    }

    if (mod.iconURL.length) {
        // AFNetworking category will set image asynchronously and keep placeholder meanwhile
        [self.modIconView setImageWithURL:[NSURL URLWithString:mod.iconURL] placeholderImage:placeholder];
    } else {
        self.modIconView.image = placeholder;
    }

    // Update toggle button title based on disabled flag
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

@end