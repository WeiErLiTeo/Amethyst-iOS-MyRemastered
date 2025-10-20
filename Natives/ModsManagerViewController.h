#import <UIKit/UIKit.h>
#import "ModVersionViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Enum to manage the controller's state
typedef NS_ENUM(NSInteger, ModsManagerMode) {
    ModsManagerModeLocal,
    ModsManagerModeOnline
};

@interface ModsManagerViewController : UIViewController

@property (nonatomic, copy, nullable) NSString *profileName;

// Batch operation properties
@property (nonatomic, assign) BOOL isBatchMode;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedModPaths;

// Properties for online search
@property (nonatomic, assign) ModsManagerMode currentMode;
@property (nonatomic, strong) NSMutableArray<ModItem *> *onlineSearchResults;

@end

NS_ASSUME_NONNULL_END
