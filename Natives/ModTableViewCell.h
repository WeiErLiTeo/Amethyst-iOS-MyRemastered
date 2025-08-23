//
//  ModTableViewCell.h
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import <UIKit/UIKit.h>
#import "ModItem.h"

@protocol ModTableViewCellDelegate <NSObject>
- (void)modCellDidTapToggle:(UITableViewCell *)cell;
- (void)modCellDidTapDelete:(UITableViewCell *)cell;
@end

@interface ModTableViewCell : UITableViewCell

@property (nonatomic, weak) id<ModTableViewCellDelegate> delegate;
- (void)configureWithMod:(ModItem *)mod;

@end