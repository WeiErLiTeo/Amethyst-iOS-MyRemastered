#import <UIKit/UIKit.h>

@class MarqueeLabel;

NS_ASSUME_NONNULL_BEGIN

@interface FileTableViewCell : UITableViewCell

@property (nonatomic, strong, readonly) MarqueeLabel *nameLabel;

@end

NS_ASSUME_NONNULL_END
