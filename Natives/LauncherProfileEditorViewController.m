//
//  LauncherProfileEditorViewController.m
//  Amethyst-iOS-MyRemastered
//
//  Fixed: safePathForEnv signature, added method prototypes for setupVersionPicker/changeVersionType,
//  implemented UIPickerViewDataSource methods to avoid protocol warnings, defensive listFilesAtPath.
//

#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherProfileEditorViewController.h"
#import "MinecraftResourceUtils.h"
#import "PickTextField.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface LauncherProfileEditorViewController() <UIPickerViewDataSource, UIPickerViewDelegate>
@property(nonatomic) NSString* oldName;

@property(nonatomic) NSArray<NSDictionary *> *versionList;
@property(nonatomic) UITextField* versionTextField;
@property(nonatomic) UISegmentedControl* versionTypeControl;
@property(nonatomic) UIPickerView* versionPickerView;
@property(nonatomic) UIToolbar* versionPickerToolbar;
@property(nonatomic) int versionSelectedAt;

// forward declarations so calls in viewDidLoad compile
- (void)setupVersionPicker;
- (void)changeVersionType:(UISegmentedControl *)sender;
@end

@implementation LauncherProfileEditorViewController

- (void)viewDidLoad {
    // Setup navigation bar & appearance
    self.title = localize(@"Edit profile", nil);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(actionDone)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(actionClose)];
    self.navigationController.modalInPresentation = YES;
    self.prefSectionsVisible = YES;

    // Setup preference getter and setter
    __weak LauncherProfileEditorViewController *weakSelf = self;
    self.getPreference = ^id(NSString *section, NSString *key){
        NSString *value = weakSelf.profile[key];
        if (value.length > 0 || ![weakSelf isPickFieldAtSection:section key:key]) {
            return value;
        } else {
            return @"(default)";
        }
    };
    self.setPreference = ^(NSString *section, NSString *key, NSString *value){
        if ([value isEqualToString:@"(default)"] && [weakSelf isPickFieldAtSection:section key:key]) {
            [weakSelf.profile removeObjectForKey:key];
        } else if (value) {
            weakSelf.profile[key] = value;
        }
    };

    // Obtain all the lists
    self.oldName = self.getPreference(nil, @"name");
    if ([self.oldName length] == 0) {
        self.setPreference(nil, @"name", @"New Profile");
    }
    NSArray *rendererKeys = getRendererKeys(YES);
    NSArray *rendererList = getRendererNames(YES);

    // Use safe listFilesAtPath: (defensive)
    NSArray *touchControlList = [self listFilesAtPath:[self safePathForEnv:@"POJAV_HOME" subpath:@"controlmap"]];
    NSArray *gamepadControlList = [self listFilesAtPath:[self safePathForEnv:@"POJAV_HOME" subpath:@"controlmap/gamepads"]];

    NSMutableArray *javaList = [getPrefObject(@"java.java_homes") allKeys].mutableCopy;
    [javaList sortUsingSelector:@selector(compare:)];
    if (javaList.count > 0) javaList[0] = @"(default)";

    // Setup version picker
    [self setupVersionPicker];
    id typeVersionPicker = ^void(UITableViewCell *cell, NSString *section, NSString *key, NSDictionary *item){
        self.typeTextField(cell, section, key, item);
        UITextField *textField = (id)cell.accessoryView;
        weakSelf.versionTextField = textField;
        textField.inputAccessoryView = weakSelf.versionPickerToolbar;
        textField.inputView = weakSelf.versionPickerView;
        // Auto pick version type
        if (self.versionList) return;
        if ([MinecraftResourceUtils findVersion:textField.text inList:localVersionList]) {
            self.versionTypeControl.selectedSegmentIndex = 0;
        } else {
            NSDictionary *selected = (id)[MinecraftResourceUtils findVersion:textField.text inList:remoteVersionList];
            if (selected) {
                NSArray *types = @[@"installed", @"release", @"snapshot", @"old_beta", @"old_alpha"];
                NSString *type = selected[@"type"];
                NSInteger idx = [types indexOfObject:type];
                if (idx != NSNotFound) self.versionTypeControl.selectedSegmentIndex = idx;
                else self.versionTypeControl.selectedSegmentIndex = 0;
            } else {
                // Version not found
                self.versionTypeControl.selectedSegmentIndex = 0;
            }
        }
        self.versionSelectedAt = -1;
        [self changeVersionType:nil];
    };

    self.prefContents = @[
        @[
            // General settings
            @{@"key": @"name",
              @"icon": @"tag",
              @"title": @"preference.profile.title.name",
              @"type": self.typeTextField,
              @"placeholder": self.oldName
            },
            @{@"key": @"lastVersionId",
              @"icon": @"archivebox",
              @"title": @"preference.profile.title.version",
              @"type": typeVersionPicker,
              @"placeholder": self.getPreference(nil, @"lastVersionId"),
              @"customClass": PickTextField.class
            },
            @{@"key": @"gameDir",
              @"icon": @"folder",
              @"title": @"preference.title.game_directory",
              @"type": self.typeTextField,
              @"placeholder": [NSString stringWithFormat:@". -> /Documents/instances/%@", getPrefObject(@"general.game_directory") ?: @"(default)"]
            },
            // Video and renderer settings
            @{@"key": @"renderer",
              @"icon": @"cpu",
              @"type": self.typePickField,
              @"pickKeys": rendererKeys,
              @"pickList": rendererList
            },
            // Control settings
            @{@"key": @"defaultTouchCtrl",
              @"icon": @"hand.tap",
              @"title": @"preference.profile.title.default_touch_control",
              @"type": self.typePickField,
              @"pickKeys": touchControlList,
              @"pickList": touchControlList
            },
            @{@"key": @"defaultGamepadCtrl",
              @"icon": @"gamecontroller",
              @"title": @"preference.profile.title.default_gamepad_control",
              @"type": self.typePickField,
              @"pickKeys": gamepadControlList,
              @"pickList": gamepadControlList
            },
            // Java tweaks
            @{@"key": @"javaVersion",
              @"icon": @"cube",
              @"title": @"preference.manage_runtime.header.default",
              @"type": self.typePickField,
              @"pickKeys": javaList,
              @"pickList": javaList
            },
            @{@"key": @"javaArgs",
              @"icon": @"slider.vertical.3",
              @"title": @"preference.title.java_args",
              @"type": self.typeTextField,
              @"placeholder": @"(default)"
            }
        ]
    ];

    [super viewDidLoad];
}

#pragma mark - Safe env helper

// Accept NSString* for envName to avoid incompatible-pointer warnings when passing @"POJAV_HOME"
- (NSString *)safePathForEnv:(NSString *)envName subpath:(NSString *)sub {
    if (!envName) return nil;
    const char *envC = getenv([envName UTF8String]);
    if (!envC) return nil;
    NSString *home = [NSString stringWithUTF8String:envC];
    if (!home || home.length == 0) return nil;
    return [home stringByAppendingPathComponent:sub];
}

- (void)actionClose {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)actionDone {
    // We might be saving without ending editing, so make sure textFieldDidEndEditing is always called
    UITextField *currentTextField = [self performSelector:@selector(_firstResponder)];
    if ([currentTextField isKindOfClass:UITextField.class] && [currentTextField isDescendantOfView:self.tableView]) {
        [self textFieldDidEndEditing:currentTextField];
    }

    if ([self.profile[@"name"] length] == 0 && self.oldName.length > 0) {
        // Return to its old name
        self.profile[@"name"] = self.oldName;
    }

    if ([self.oldName isEqualToString:self.profile[@"name"]]) {
        // Not a rename, directly create/replace
        PLProfiles.current.profiles[self.oldName] = self.profile;
    } else if (!PLProfiles.current.profiles[self.profile[@"name"]]) {
        // A rename, remove then re-add to update its key name
        if (self.oldName.length > 0) {
            [PLProfiles.current.profiles removeObjectForKey:self.oldName];
        }
        PLProfiles.current.profiles[self.profile[@"name"]] = self.profile;
        // Update selected name
        if ([PLProfiles.current.selectedProfileName isEqualToString:self.oldName]) {
            PLProfiles.current.selectedProfileName = self.profile[@"name"];
        }
    } else {
        // Cancel rename since a profile with the same name already exists
        showDialog(localize(@"Error", nil), localize(@"profile.error.name_exists", nil));
        // Skip dismissing this view controller
        return;
    }

    [PLProfiles.current save];

    // Notify other components that the profile changed (so mods list can refresh if needed)
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProfileDidChangeNotification" object:nil userInfo:@{@"profileName": self.profile[@"name"] ?: @""}];

    [self actionClose];

    // Call LauncherProfilesViewController's viewWillAppear
    UINavigationController *navVC = (id) ((UISplitViewController *)self.presentingViewController).viewControllers[1];
    [navVC.viewControllers[0] viewWillAppear:NO];
}

- (BOOL)isPickFieldAtSection:(NSString *)section key:(NSString *)key {
    NSDictionary *pref = [self.prefContents[0] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(key == %@)", key]].firstObject;
    return pref[@"type"] == self.typePickField;
}

- (NSArray *)listFilesAtPath:(NSString *)path {
    // Defensive: path may be nil or not a directory
    if (!path || path.length == 0) return @[@"(default)"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
        return @[@"(default)"];
    }
    NSError *err = nil;
    NSArray *items = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:&err];
    if (!items || err) return @[@"(default)"];
    NSMutableArray *files = items.mutableCopy;
    for (int i = 0; i < files.count;) {
        if ([files[i] hasSuffix:@".json"]) {
            i++;
        } else {
            [files removeObjectAtIndex:i];
        }
    }
    [files insertObject:@"(default)" atIndex:0];
    return files;
}

#pragma mark Version picker

- (void)setupVersionPicker {
    self.versionPickerView = [[UIPickerView alloc] init];
    self.versionPickerView.delegate = self;
    self.versionPickerView.dataSource = self;
    self.versionPickerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, 44.0)];

    self.versionTypeControl = [[UISegmentedControl alloc] initWithItems:@[
        localize(@"Installed", nil),
        localize(@"Releases", nil),
        localize(@"Snapshot", nil),
        localize(@"Old-beta", nil),
        localize(@"Old-alpha", nil)
    ]];
    [self.versionTypeControl addTarget:self action:@selector(changeVersionType:) forControlEvents:UIControlEventValueChanged];
    self.versionPickerToolbar.items = @[
        [[UIBarButtonItem alloc] initWithCustomView:self.versionTypeControl],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(versionClosePicker)]
    ];
    self.versionSelectedAt = -1;
    self.versionList = @[];
}

- (void)versionClosePicker {
    [self.versionTextField endEditing:YES];
    [self pickerView:self.versionPickerView didSelectRow:[self.versionPickerView selectedRowInComponent:0] inComponent:0];
}

- (void)changeVersionType:(UISegmentedControl *)sender {
    NSArray *newVersionList = self.versionList;
    if (sender || !self.versionList || self.versionList.count == 0) {
        if (self.versionTypeControl.selectedSegmentIndex == 0) {
            // installed
            newVersionList = localVersionList ?: @[];
        } else {
            NSString *type = @[@"installed", @"release", @"snapshot", @"old_beta", @"old_alpha"][self.versionTypeControl.selectedSegmentIndex];
            if (remoteVersionList) {
                newVersionList = [remoteVersionList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(type == %@)", type]];
            } else {
                newVersionList = @[];
            }
        }
    }

    if (self.versionSelectedAt == -1) {
        NSDictionary *selected = (id)[MinecraftResourceUtils findVersion:self.versionTextField.text inList:newVersionList];
        if (selected) {
            self.versionSelectedAt = [newVersionList indexOfObject:selected];
        } else {
            self.versionSelectedAt = -1;
        }
    } else {
        // Find the most matching version for this type
        NSObject *lastSelected = nil;
        if (self.versionList.count > self.versionSelectedAt && self.versionSelectedAt >= 0) {
            lastSelected = self.versionList[self.versionSelectedAt];
        }
        if (lastSelected != nil) {
            NSObject *nearest = [MinecraftResourceUtils findNearestVersion:lastSelected expectedType:self.versionTypeControl.selectedSegmentIndex];
            if (nearest != nil) {
                self.versionSelectedAt = [newVersionList indexOfObject:(id)nearest];
            }
        }
        // Bound the index
        if (newVersionList.count == 0) self.versionSelectedAt = -1;
        else self.versionSelectedAt = MAX(0, MIN(self.versionSelectedAt, (int)newVersionList.count - 1));
    }

    self.versionList = newVersionList;
    [self.versionPickerView reloadAllComponents];
    if (self.versionSelectedAt != -1 && self.versionList.count > 0) {
        [self.versionPickerView selectRow:self.versionSelectedAt inComponent:0 animated:NO];
        [self pickerView:self.versionPickerView didSelectRow:self.versionSelectedAt inComponent:0];
    }
}

#pragma mark - UIPickerViewDataSource / Delegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.versionList.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (self.versionList.count <= row) return @"";
    NSObject *object = self.versionList[row];
    if ([object isKindOfClass:[NSString class]]) {
        return (NSString*) object;
    } else if ([object respondsToSelector:@selector(valueForKey:)]) {
        id val = [object valueForKey:@"id"];
        if ([val isKindOfClass:[NSString class]]) return val;
    }
    return @"";
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (self.versionList.count == 0 || row < 0 || row >= self.versionList.count) {
        self.versionTextField.text = @"";
        return;
    }
    self.versionSelectedAt = (int)row;
    NSString *title = [self pickerView:pickerView titleForRow:row forComponent:component];
    if (title) self.versionTextField.text = title;
}

@end