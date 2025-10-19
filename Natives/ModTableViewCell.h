#import <UIKit/UIKit.h>
@class ModItem;
@class MarqueeLabel;

NS_ASSUME_NONNULL_BEGIN

// Display mode for the cell
typedef NS_ENUM(NSInteger, ModTableViewCellDisplayMode) {
    ModTableViewCellDisplayModeLocal,
    ModTableViewCellDisplayModeOnline
};

@protocol ModTableViewCellDelegate <NSObject>
@optional
- (void)modCellDidTapToggle:(UITableViewCell *)cell;
- (void)modCellDidTapInfoButton:(UITableViewCell *)cell;
- (void)modCellDidTapDownload:(UITableViewCell *)cell;
@end

@interface ModTableViewCell : UITableViewCell

// --- UI Elements ---
@property (nonatomic, strong) UIImageView *modIconView;
@property (nonatomic, strong) MarqueeLabel *nameLabel;
@property (nonatomic, strong) UILabel *authorLabel; // For online author
@property (nonatomic, strong) MarqueeLabel *descLabel;
@property (nonatomic, strong) UILabel *statsLabel; // For downloads, likes, etc.
@property (nonatomic, strong) UILabel *categoryLabel; // For categories
@property (nonatomic, strong) UIStackView *loaderBadgesStackView; // Container for loader icons

// --- Action Buttons ---
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UIButton *downloadButton; // For online mode
@property (nonatomic, strong) UIButton *openLinkButton;

@property (nonatomic, weak) id<ModTableViewCellDelegate> delegate;

// --- State Properties ---
@property (nonatomic, assign) BOOL isBatchMode;

// --- Configuration ---
- (void)configureWithMod:(ModItem *)mod displayMode:(ModTableViewCellDisplayMode)mode;

// --- State Updates ---
- (void)updateToggleState:(BOOL)disabled;
- (void)updateBatchSelectionState:(BOOL)isSelected batchMode:(BOOL)batchMode;

@end

NS_ASSUME_NONNULL_END
