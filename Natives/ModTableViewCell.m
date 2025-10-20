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
@end

@implementation ModTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor]; // Use clear color for custom background view
        self.contentView.backgroundColor = [UIColor systemBackgroundColor];

        // --- Initialization of UI Elements ---
        _modIconView = [self createImageViewWithCornerRadius:4];

        // Replace UILabels with MarqueeLabels for scrolling long text
        _nameLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero rate:60.0 andFadeLength:10.0];
        _nameLabel.marqueeType = MLContinuous;
        _nameLabel.font = [UIFont boldSystemFontOfSize:13];
        _nameLabel.textColor = [UIColor labelColor];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _authorLabel = [self createLabelWithFont:[UIFont systemFontOfSize:9] textColor:[UIColor secondaryLabelColor] numberOfLines:1];

        _descLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero rate:50.0 andFadeLength:10.0];
        _descLabel.marqueeType = MLContinuous;
        _descLabel.numberOfLines = 1;
        _descLabel.font = [UIFont systemFontOfSize:9];
        _descLabel.textColor = [UIColor grayColor];
        _descLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _statsLabel = [self createLabelWithFont:[UIFont systemFontOfSize:9] textColor:[UIColor secondaryLabelColor] numberOfLines:1];
        _categoryLabel = [self createLabelWithFont:[UIFont systemFontOfSize:9] textColor:[UIColor systemBlueColor] numberOfLines:1];

        _enableSwitch = [[UISwitch alloc] init];
        _enableSwitch.transform = CGAffineTransformMakeScale(0.75, 0.75); // Scale down for compact view
        _enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [_enableSwitch addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventValueChanged];

        _downloadButton = [self createButtonWithTitle:@"下载" titleColor:[UIColor whiteColor] action:@selector(downloadTapped)];
        _downloadButton.backgroundColor = [UIColor systemGreenColor];
        _downloadButton.layer.cornerRadius = 10;
        _downloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        _downloadButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);

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
        [self.contentView addSubview:_enableSwitch];
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
    imageView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    return imageView;
}

- (UILabel *)createLabelWithFont:(UIFont *)font textColor:(UIColor *)color numberOfLines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
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
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
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
    CGFloat padding = 7.0;
    CGFloat iconSize = 36.0;

    // --- Common Left-aligned Elements ---
    [NSLayoutConstraint activateConstraints:@[
        [_modIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [_modIconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_modIconView.widthAnchor constraintEqualToConstant:iconSize],
        [_modIconView.heightAnchor constraintEqualToConstant:iconСизе],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_modIconView.trailingAnchor constant:8],
        [_nameLabel.topAnchor constraintEqualToAnchor:_modIconView.topAnchor],

        [_descLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_descLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:1],

        [_authorLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_authorLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:1],
        [_statsLabel.leadingAnchor constraintEqualToAnchor:_authorLabel.trailingAnchor constant:4],
        [_statsLabel.centerYAnchor constraintEqualToAnchor:_authorLabel.centerYAnchor],
    ]];

    // --- Right-aligned Action Buttons (Side-by-side) ---
    // The rightmost button (_enableSwitch OR _downloadButton) is anchored to the trailing edge.
    [_downloadButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
    [_downloadButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    [_enableSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
    [_enableSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

    // The info button (_openLinkButton) is anchored to the LEADING edge of the rightmost button area.
    // We use the switch as the anchor since it occupies the same space as the download button.
    [_openLinkButton.trailingAnchor constraintEqualToAnchor:_enableSwitch.leadingAnchor constant:-4],
    [_openLinkButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    [_openLinkButton.widthAnchor constraintEqualToConstant:28], // Give it a fixed width
    [_openLinkButton.heightAnchor constraintEqualToConstant:28], // Give it a fixed height

    // --- Text Content Trailing Constraints (CRITICAL for fixing button taps) ---
    // All text labels must end before the info button begins.
    [_nameLabel.trailingAnchor constraintEqualToAnchor:_openLinkButton.leadingAnchor constant:-padding],
    [_descLabel.trailingAnchor constraintEqualToAnchor:_openLinkButton.leadingAnchor constant:-padding],
    [_statsLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_openLinkButton.leadingAnchor constant:-padding],

    // --- Loader Badges ---
    // Badges are positioned between the name label and the info button.
    [_loaderBadgesStackView.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
    [_loaderBadgesStackView.heightAnchor constraintEqualToConstant:12],
    [_loaderBadgesStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_nameLabel.trailingAnchor constant:4],
    [_loaderBadgesStackView.trailingAnchor constraintEqualToAnchor:_openLinkButton.leadingAnchor constant:-4],
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

    // Show local elements
    _openLinkButton.hidden = NO; // Globe icon should be visible for local mods too
    _enableSwitch.hidden = NO;
    _loaderBadgesStackView.hidden = NO;

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

    [self updateToggleState:mod.disabled];
}

- (void)configureForOnlineMode:(ModItem *)mod {
    // Hide local elements
    _enableSwitch.hidden = YES;
    _loaderBadgesStackView.hidden = YES; // Badges aren't shown in online mode for now

    // Show online elements
    _authorLabel.hidden = NO;
    _statsLabel.hidden = NO;
    _downloadButton.hidden = NO;
    _openLinkButton.hidden = NO;

    _authorLabel.text = [NSString stringWithFormat:@"by %@", mod.author ?: @"Unknown"];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *downloadsStr = [formatter stringFromNumber:mod.downloads ?: @0];

    _statsLabel.text = [NSString stringWithFormat:@"%@ downloads", downloadsStr];
}


#pragma mark - State Updates

- (void)updateToggleState:(BOOL)disabled {
    [_enableSwitch setOn:!disabled animated:YES];
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
