#import "ModTableViewCell.h"
#import "ModItem.h"
#import "ModService.h"
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#import "UIKit+AFNetworking.h"
#pragma clang diagnostic pop

@interface ModTableViewCell ()
@property (nonatomic, strong) ModItem *currentMod;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *localModeConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *onlineModeConstraints;
@end

@implementation ModTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor systemBackgroundColor];

        // --- Initialization of UI Elements ---
        _modIconView = [self createImageViewWithCornerRadius:8];
        _nameLabel = [self createLabelWithFont:[UIFont boldSystemFontOfSize:16] textColor:[UIColor labelColor] numberOfLines:1];
        _authorLabel = [self createLabelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor secondaryLabelColor] numberOfLines:1];
        _descLabel = [self createLabelWithFont:[UIFont systemFontOfSize:13] textColor:[UIColor grayColor] numberOfLines:2];
        _statsLabel = [self createLabelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor secondaryLabelColor] numberOfLines:1];
        _categoryLabel = [self createLabelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor systemBlueColor] numberOfLines:1];

        _toggleButton = [self createButtonWithAction:@selector(toggleTapped)];
        _deleteButton = [self createButtonWithTitle:@"删除" titleColor:[UIColor systemRedColor] action:@selector(deleteTapped)];
        _downloadButton = [self createButtonWithTitle:@"下载" titleColor:[UIColor systemGreenColor] action:@selector(downloadTapped)];
        _openLinkButton = [self createButtonWithImage:[UIImage systemImageNamed:@"globe"] action:@selector(openLinkTapped)];

        _loaderBadgesStackView = [[UIStackView alloc] init];
        _loaderBadgesStackView.translatesAutoresizingMaskIntoConstraints = NO;
        _loaderBadgesStackView.axis = UILayoutConstraintAxisHorizontal;
        _loaderBadgesStackView.spacing = 4;
        _loaderBadgesStackView.alignment = UIStackViewAlignmentCenter;

        // Add subviews
        [self.contentView addSubview:_loaderBadgesStackView];
        [self.contentView addSubview:_modIconView];
        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_authorLabel];
        [self.contentView addSubview:_descLabel];
        [self.contentView addSubview:_statsLabel];
        [self.contentView addSubview:_categoryLabel];
        [self.contentView addSubview:_toggleButton];
        [self.contentView addSubview:_deleteButton];
        [self.contentView addSubview:_downloadButton];
        [self.contentView addSubview:_openLinkButton];

        [self setupConstraints];
    }
    return self;
}

#pragma mark - UI Element Factory Methods

- (UIImageView *)createImageViewWithCornerRadius:(CGFloat)radius {
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.layer.cornerRadius = radius;
    imageView.clipsToBounds = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1.0].CGColor;
    imageView.layer.borderWidth = 1.0;
    return imageView;
}

- (UILabel *)createLabelWithFont:(UIFont *)font textColor:(UIColor *)color numberOfLines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    return label;
}

- (UIButton *)createButtonWithAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)createButtonWithTitle:(NSString *)title titleColor:(UIColor *)color action:(SEL)action {
    UIButton *button = [self createButtonWithAction:action];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    return button;
}

- (UIButton *)createButtonWithImage:(UIImage *)image action:(SEL)action {
    UIButton *button = [self createButtonWithAction:action];
    [button setImage:image forState:UIControlStateNormal];
    return button;
}

- (UIImageView *)createBadgeImageView:(NSString *)imageName {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    return imageView;
}

#pragma mark - Auto Layout Constraints

- (void)setupConstraints {
    CGFloat padding = 12.0;
    CGFloat iconSize = 76.0;

    // Common constraints for all modes
    [NSLayoutConstraint activateConstraints:@[
        [_modIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [_modIconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:padding],
        [_modIconView.widthAnchor constraintEqualToConstant:iconSize],
        [_modIconView.heightAnchor constraintEqualToConstant:iconSize],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_modIconView.trailingAnchor constant:padding],
        [_nameLabel.topAnchor constraintEqualToAnchor:_modIconView.topAnchor],

        [_loaderBadgesStackView.leadingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor constant:8],
        [_loaderBadgesStackView.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
        [_loaderBadgesStackView.heightAnchor constraintEqualToConstant:16],

        [_descLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_descLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_descLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
    ]];

    // Constraints specific to Local Mode
    self.localModeConstraints = @[
        [_nameLabel.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor constant:-padding],
        [_toggleButton.trailingAnchor constraintEqualToAnchor:_deleteButton.leadingAnchor constant:-8],
        [_deleteButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_toggleButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_deleteButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    ];

    // Constraints specific to Online Mode
    self.onlineModeConstraints = @[
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_authorLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_authorLabel.topAnchor constraintEqualToAnchor:_descLabel.bottomAnchor constant:6],
        [_statsLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_statsLabel.topAnchor constraintEqualToAnchor:_authorLabel.bottomAnchor constant:4],
        [_downloadButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_downloadButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    ];
}

#pragma mark - Configuration

- (void)configureWithMod:(ModItem *)mod displayMode:(ModTableViewCellDisplayMode)mode {
    self.currentMod = mod;

    _nameLabel.text = mod.displayName ?: mod.fileName;
    _descLabel.text = mod.modDescription;

    if (mod.icon) {
        _modIconView.image = mod.icon;
    } else if (mod.iconURL) {
        [_modIconView setImageWithURL:[NSURL URLWithString:mod.iconURL] placeholderImage:[UIImage systemImageNamed:@"puzzlepiece.extension"]];
    } else {
        _modIconView.image = [UIImage systemImageNamed:@"puzzlepiece.extension"];
    }

    if (mode == ModTableViewCellDisplayModeLocal) {
        [self configureForLocalMode:mod];
    } else {
        [self configureForOnlineMode:mod];
    }
}

- (void)configureForLocalMode:(ModItem *)mod {
    // Hide online elements
    _authorLabel.hidden = YES;
    _statsLabel.hidden = YES;
    _categoryLabel.hidden = YES;
    _downloadButton.hidden = YES;
    _loaderBadgesStackView.hidden = NO;

    // Show local elements
    _toggleButton.hidden = NO;
    _deleteButton.hidden = NO;

    // Clear previous badges
    for (UIView *view in self.loaderBadgesStackView.arrangedSubviews) {
        [self.loaderBadgesStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    // Add new badges based on mod properties
    if (mod.isFabric) {
        [self.loaderBadgesStackView addArrangedSubview:[self createBadgeImageView:@"fabric_logo"]];
    }
    if (mod.isForge) {
        [self.loaderBadgesStackView addArrangedSubview:[self createBadgeImageView:@"forge_logo"]];
    }
    if (mod.isNeoForge) {
        [self.loaderBadgesStackView addArrangedSubview:[self createBadgeImageView:@"neoforge_logo"]];
    }

    // Activate local constraints
    [NSLayoutConstraint deactivateConstraints:self.onlineModeConstraints];
    [NSLayoutConstraint activateConstraints:self.localModeConstraints];

    [self updateToggleState:mod.disabled];
}

- (void)configureForOnlineMode:(ModItem *)mod {
    // Hide local elements
    _toggleButton.hidden = YES;
    _deleteButton.hidden = YES;

    // Show online elements
    _authorLabel.hidden = NO;
    _statsLabel.hidden = NO;
    _downloadButton.hidden = NO;

    // Activate online constraints
    [NSLayoutConstraint deactivateConstraints:self.localModeConstraints];
    [NSLayoutConstraint activateConstraints:self.onlineModeConstraints];

    _authorLabel.text = [NSString stringWithFormat:@"by %@", mod.author ?: @"Unknown"];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *downloadsStr = [formatter stringFromNumber:mod.downloads ?: @0];

    _statsLabel.text = [NSString stringWithFormat:@"%@ downloads", downloadsStr];
}


#pragma mark - State Updates

- (void)updateToggleState:(BOOL)disabled {
    NSString *title = disabled ? @"启用" : @"禁用";
    UIColor *color = disabled ? [UIColor systemBlueColor] : [UIColor systemOrangeColor];
    [_toggleButton setTitle:title forState:UIControlStateNormal];
    [_toggleButton setTitleColor:color forState:UIControlStateNormal];
    
    self.contentView.alpha = disabled ? 0.6 : 1.0;
}

- (void)updateBatchSelectionState:(BOOL)isSelected batchMode:(BOOL)batchMode {
    self.isBatchMode = batchMode;
    if (batchMode && isSelected) {
        self.backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.3];
    } else {
        self.backgroundColor = [UIColor systemBackgroundColor];
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

- (void)downloadTapped {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapDownload:)]) {
        [self.delegate modCellDidTapDownload:self];
    }
}

- (void)openLinkTapped {
    if ([self.delegate respondsToSelector:@selector(modCellDidTapOpenLink:)]) {
        [self.delegate modCellDidTapOpenLink:self];
    }
}

@end
#pragma clang diagnostic pop
