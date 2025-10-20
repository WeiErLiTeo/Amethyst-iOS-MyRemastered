#import "FileTableViewCell.h"
#import "MarqueeLabel.h"

@implementation FileTableViewCell

@synthesize nameLabel = _nameLabel;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        // Initialize and configure the MarqueeLabel
        _nameLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        _nameLabel.rate = 60.0; // Speed of the scroll
        _nameLabel.fadeLength = 10.0f; // Length of the fade at the edges
        _nameLabel.marqueeType = MLContinuous; // Continuous scrolling
        _nameLabel.animationDelay = 2.0; // Delay before scrolling starts
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_nameLabel];

        // Setup Auto Layout constraints
        [NSLayoutConstraint activateConstraints:@[
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_nameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    }
    return self;
}

@end
