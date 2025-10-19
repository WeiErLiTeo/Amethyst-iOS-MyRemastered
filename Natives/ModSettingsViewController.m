#import "ModSettingsViewController.h"
#import "LauncherPreferences.h"
#import "utils.h"

@implementation ModSettingsViewController

- (void)viewDidLoad {
    self.title = localize(@"preference.section.title.mod_settings", @"Mod Settings");

    // Define a re-usable block for settings that are not available in-game
    BOOL(^whenNotInGame)() = ^BOOL(){
        return self.navigationController != nil;
    };

    self.prefSections = @[@"mod_management"];

    self.prefContents = @[
        @[
            // Section Icon
            @{@"icon": @"wrench.and.screwdriver"},

            // Toggle for Batch Management
            @{@"key": @"enable_batch_management",
              @"hasDetail": @YES,
              @"icon": @"square.stack.3d.up.fill",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame,
              @"action": ^(BOOL enabled){
                  // Post notification on change
                  [[NSNotificationCenter defaultCenter] postNotificationName:@"ModSettingsChanged" object:nil];
              }
            },

            // Toggle for Refresh Button
            @{@"key": @"enable_refresh_button",
              @"hasDetail": @YES,
              @"icon": @"arrow.clockwise",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame,
              @"action": ^(BOOL enabled){
                  // Post notification on change
                  [[NSNotificationCenter defaultCenter] postNotificationName:@"ModSettingsChanged" object:nil];
              }
            },
        ],
    ];

    [super viewDidLoad];
}

@end
