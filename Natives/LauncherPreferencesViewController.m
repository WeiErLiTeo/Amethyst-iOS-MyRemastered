#import <Foundation/Foundation.h>

#import "DBNumberedSlider.h"
#import "HostManagerBridge.h"
#import "LauncherNavigationController.h"
#import "LauncherMenuViewController.h"
#import "LauncherPreferences.h"
#import "LauncherPreferencesViewController.h"
#import "LauncherPrefContCfgViewController.h"
#import "LauncherPrefManageJREViewController.h"
#import "UIKit+hook.h"

#import "config.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#import "ImageCropperViewController.h"
#import "CustomIconManager.h"
#import "ModSettingsViewController.h"

@interface LauncherPreferencesViewController()
@property(nonatomic) NSArray<NSString*> *rendererKeys, *rendererList;
@end

@implementation LauncherPreferencesViewController

- (id)init {
    self = [super init];
    self.title = localize(@"Settings", nil);
    return self;
}

- (NSString *)imageName {
    return @"MenuSettings";
}

- (void)openImagePicker {
    // 检查是否已经显示了图片选择器
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *window in scene.windows) {
                    for (UIView *view in window.subviews) {
                        if ([view isKindOfClass:[UIAlertController class]] || 
                            [view isKindOfClass:[UIImagePickerController class]]) {
                            // 如果已经显示了相关控制器，直接返回
                            return;
                        }
                    }
                }
            }
        }
    }
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    
    // 延迟显示图片选择器，避免与UIAlertController冲突
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:imagePicker animated:YES completion:nil];
    });
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        // 在图片选择器完全关闭后再处理图片
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
            if (!selectedImage) {
                [self showCustomIconError:@"无法获取选中的图片"];
                return;
            }
            
            // 显示处理中的提示
            [self showProcessingIndicator];
            
            // 检查图片是否为正方形
            if (selectedImage.size.width != selectedImage.size.height) {
                // 如果不是正方形，打开裁剪界面
                ImageCropperViewController *cropperVC = [[ImageCropperViewController alloc] initWithImage:selectedImage];
                __weak typeof(self) weakSelf = self;
                cropperVC.completionHandler = ^(UIImage * _Nullable croppedImage) {
                    if (croppedImage) {
                        // 保存裁剪后的图片
                        [[CustomIconManager sharedManager] saveCustomIcon:croppedImage withCompletion:^(BOOL success, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (success) {
                                    [weakSelf showSuccessMessage:@"图片已保存，您可以在应用图标设置中选择自定义图标"];
                                    // 更新应用图标选择器的显示
                                    [weakSelf.tableView reloadData];
                                } else {
                                    NSString *errorMessage = error.localizedDescription ?: @"保存自定义图标失败";
                                    [weakSelf showCustomIconError:errorMessage];
                                }
                            });
                        }];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf showCustomIconError:@"图片裁剪已取消"];
                        });
                    }
                };
                [weakSelf.navigationController pushViewController:cropperVC animated:YES];
            } else {
                // 如果是正方形，直接保存
                [[CustomIconManager sharedManager] saveCustomIcon:selectedImage withCompletion:^(BOOL success, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            [self showSuccessMessage:@"图片已保存，您可以在应用图标设置中选择自定义图标"];
                            // 更新应用图标选择器的显示
                            [self.tableView reloadData];
                        } else {
                            NSString *errorMessage = error.localizedDescription ?: @"保存自定义图标失败";
                            [self showCustomIconError:errorMessage];
                        }
                    });
                }];
            }
        });
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showCustomIconError:@"图片选择已取消"];
        });
    }];
}

#pragma mark - Custom Icon Helper Methods

- (void)showProcessingIndicator {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"处理中" message:@"正在处理您选择的图片..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    
    // 2秒后自动关闭提示
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showSuccessMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"成功" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCustomIconError:(NSString *)errorMessage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewDidLoad
{
    self.getPreference = ^id(NSString *section, NSString *key){
        NSString *keyFull = [NSString stringWithFormat:@"%@.%@", section, key];
        return getPrefObject(keyFull);
    };
    self.setPreference = ^(NSString *section, NSString *key, id value){
        NSString *keyFull = [NSString stringWithFormat:@"%@.%@", section, key];
        setPrefObject(keyFull, value);
    };
    
    self.hasDetail = YES;
    self.prefDetailVisible = self.navigationController == nil;
    
    self.prefSections = @[@"general", @"video", @"control", @"java", @"debug"];

    self.rendererKeys = getRendererKeys(NO);
    self.rendererList = getRendererNames(NO);
    
    BOOL(^whenNotInGame)() = ^BOOL(){
        return self.navigationController != nil;
    };
    self.prefContents = @[
        @[
            // General settings
            @{@"icon": @"cube"},
            @{@"key": @"mod_settings",
              @"hasDetail": @YES,
              @"icon": @"wrench.and.screwdriver",
              @"type": self.typeChildPane,
              @"class": @"ModSettingsViewController"
            },
            @{@"key": @"check_sha",
              @"hasDetail": @YES,
              @"icon": @"lock.shield",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"cosmetica",
              @"hasDetail": @YES,
              @"icon": @"eyeglasses",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_logging",
              @"hasDetail": @YES,
              @"icon": @"doc.badge.gearshape",
              @"type": self.typeSwitch,
              @"action": ^(BOOL enabled){
                  debugLogEnabled = enabled;
                  NSLog(@"[Debugging] Debug log enabled: %@", enabled ? @"YES" : @"NO");
              }
            },
            @{@"key": @"appicon",
              @"hasDetail": @YES,
              @"icon": @"paintbrush",
              @"type": self.typePickField,
              @"enableCondition": ^BOOL(){
                  return UIApplication.sharedApplication.supportsAlternateIcons;
              },
              @"action": ^void(NSString *iconName) {
                  if ([iconName isEqualToString:@"AppIcon-Light"]) {
                      iconName = nil;
                      [[CustomIconManager sharedManager] removeCustomIcon];
                  } else if ([iconName isEqualToString:@"CustomIcon"]) {
                      // 检查自定义图标是否存在
                      if (![[CustomIconManager sharedManager] hasCustomIcon]) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"请先设置自定义应用图标：设置 > 自定义应用图标" preferredStyle:UIAlertControllerStyleAlert];
                              UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                              [alert addAction:okAction];
                              [self presentViewController:alert animated:YES completion:nil];
                          });
                          // 重置选择为默认图标
                          dispatch_async(dispatch_get_main_queue(), ^{
                              [self.tableView reloadData];
                          });
                          return;
                      }
                      
                      // 设置自定义图标
                      [[CustomIconManager sharedManager] setCustomIconWithCompletion:^(BOOL success, NSError * _Nullable error) {
                          if (!success) {
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  NSLog(@"Error in appicon: %@", error);
                                  showDialog(localize(@"Error", nil), error.localizedDescription);
                              });
                          }
                      }];
                      return;
                  }
                  [UIApplication.sharedApplication setAlternateIconName:iconName completionHandler:^(NSError * _Nullable error) {
                      if (error == nil) return;
                      NSLog(@"Error in appicon: %@", error);
                      showDialog(localize(@"Error", nil), error.localizedDescription);
                  }];
              },
              @"pickKeys": @[
                  @"AppIcon-Light",
                  @"CustomIcon"
              ],
              @"pickList": @[
                  localize(@"preference.title.appicon-default", nil),
                  localize(@"preference.title.appicon-custom", nil)
              ]
            },
            @{@"key": @"custom_appicon",
              @"hasDetail": @YES,
              @"icon": @"photo",
              @"type": self.typeButton,
              @"enableCondition": ^BOOL(){
                  return UIApplication.sharedApplication.supportsAlternateIcons;
              },
              @"action": ^void(){
                  // 打开图片选择器
                  [self openImagePicker];
              }
            },
            @{@"key": @"hidden_sidebar",
              @"hasDetail": @YES,
              @"icon": @"sidebar.leading",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"reset_warnings",
              @"icon": @"exclamationmark.triangle",
              @"type": self.typeButton,
              @"enableCondition": whenNotInGame,
              @"action": ^void(){
                  resetWarnings();
              }
            },
            @{@"key": @"reset_settings",
              @"icon": @"trash",
              @"type": self.typeButton,
              @"enableCondition": whenNotInGame,
              @"requestReload": @YES,
              @"showConfirmPrompt": @YES,
              @"destructive": @YES,
              @"action": ^void(){
                  loadPreferences(YES);
                  [self.tableView reloadData];
              }
            },
            @{@"key": @"erase_demo_data",
              @"icon": @"trash",
              @"type": self.typeButton,
              @"enableCondition": ^BOOL(){
                  NSString *demoPath = [NSString stringWithFormat:@"%s/.demo", getenv("POJAV_HOME")];
                  int count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:demoPath error:nil].count;
                  return whenNotInGame() && count > 0;
              },
              @"showConfirmPrompt": @YES,
              @"destructive": @YES,
              @"action": ^void(){
                  NSString *demoPath = [NSString stringWithFormat:@"%s/.demo", getenv("POJAV_HOME")];
                  NSError *error;
                  if([NSFileManager.defaultManager removeItemAtPath:demoPath error:&error]) {
                      [NSFileManager.defaultManager createDirectoryAtPath:demoPath
                                              withIntermediateDirectories:YES attributes:nil error:nil];
                      [NSFileManager.defaultManager changeCurrentDirectoryPath:demoPath];
                      if (getenv("DEMO_LOCK")) {
                          [(LauncherNavigationController *)self.navigationController fetchLocalVersionList];
                      }
                  } else {
                      NSLog(@"Error in erase_demo_data: %@", error);
                      showDialog(localize(@"Error", nil), error.localizedDescription);
                  }
              }
            }
        ], @[
            // Video and renderer settings
            @{@"icon": @"video"},
            @{@"key": @"renderer",
              @"hasDetail": @YES,
              @"icon": @"cpu",
              @"type": self.typePickField,
              @"enableCondition": whenNotInGame,
              @"pickKeys": self.rendererKeys,
              @"pickList": self.rendererList
            },
            @{@"key": @"resolution",
              @"hasDetail": @YES,
              @"icon": @"viewfinder",
              @"type": self.typeSlider,
              @"min": @(25),
              @"max": @(150)
            },
            @{@"key": @"max_framerate",
              @"hasDetail": @YES,
              @"icon": @"timelapse",
              @"type": self.typeSwitch,
              @"enableCondition": ^BOOL(){
                  return whenNotInGame() && (UIScreen.mainScreen.maximumFramesPerSecond > 60);
              }
            },
            @{@"key": @"performance_hud",
              @"hasDetail": @YES,
              @"icon": @"waveform.path.ecg",
              @"type": self.typeSwitch,
              @"enableCondition": ^BOOL(){
                  return [CAMetalLayer instancesRespondToSelector:@selector(developerHUDProperties)];
              }
            },
            @{@"key": @"fullscreen_airplay",
              @"hasDetail": @YES,
              @"icon": @"airplayvideo",
              @"type": self.typeSwitch,
              @"action": ^(BOOL enabled){
                  if (self.navigationController != nil) return;
                  if (UIApplication.sharedApplication.connectedScenes.count < 2) return;
                  if (enabled) {
                      [self.presentingViewController performSelector:@selector(switchToExternalDisplay)];
                  } else {
                      [self.presentingViewController performSelector:@selector(switchToInternalDisplay)];
                  }
              }
            },
            @{@"key": @"silence_other_audio",
              @"hasDetail": @YES,
              @"icon": @"speaker.slash",
              @"type": self.typeSwitch
            },
            @{@"key": @"silence_with_switch",
              @"hasDetail": @YES,
              @"icon": @"speaker.zzz",
              @"type": self.typeSwitch
            },
            @{@"key": @"allow_microphone",
              @"hasDetail": @YES,
              @"icon": @"mic",
              @"type": self.typeSwitch
            },
        ], @[
            // Control settings
            @{@"icon": @"gamecontroller"},
            @{@"key": @"default_gamepad_ctrl",
                @"icon": @"hammer",
                @"type": self.typeChildPane,
                @"enableCondition": whenNotInGame,
                @"canDismissWithSwipe": @NO,
                @"class": LauncherPrefContCfgViewController.class
            },
            @{@"key": @"hardware_hide",
                @"icon": @"eye.slash",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"recording_hide",
                @"icon": @"eye.slash",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"gesture_mouse",
                @"icon": @"cursorarrow.click",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"gesture_hotbar",
                @"icon": @"hand.tap",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"disable_haptics",
                @"icon": @"wave.3.left",
                @"hasDetail": @NO,
                @"type": self.typeSwitch,
            },
            @{@"key": @"slideable_hotbar",
                @"hasDetail": @YES,
                @"icon": @"slider.horizontal.below.rectangle",
                @"type": self.typeSwitch
            },
            @{@"key": @"press_duration",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.click.badge.clock",
                @"type": self.typeSlider,
                @"min": @(100),
                @"max": @(1000),
            },
            @{@"key": @"button_scale",
                @"hasDetail": @YES,
                @"icon": @"aspectratio",
                @"type": self.typeSlider,
                @"min": @(50), // 80?
                @"max": @(500)
            },
            @{@"key": @"mouse_scale",
                @"hasDetail": @YES,
                @"icon": @"arrow.up.left.and.arrow.down.right.circle",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"mouse_speed",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.motionlines",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"virtmouse_enable",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.rays",
                @"type": self.typeSwitch
            },
            @{@"key": @"gyroscope_enable",
                @"hasDetail": @YES,
                @"icon": @"gyroscope",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            },
            @{@"key": @"gyroscope_invert_x_axis",
                @"hasDetail": @YES,
                @"icon": @"arrow.left.and.right",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            },
            @{@"key": @"gyroscope_sensitivity",
                @"hasDetail": @YES,
                @"icon": @"move.3d",
                @"type": self.typeSlider,
                @"min": @(50),
                @"max": @(300),
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            }
        ], @[
        // Java tweaks
            @{@"icon": @"sparkles"},
            @{@"key": @"manage_runtime",
                @"hasDetail": @YES,
                @"icon": @"cube",
                @"type": self.typeChildPane,
                @"canDismissWithSwipe": @YES,
                @"class": LauncherPrefManageJREViewController.class,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"java_args",
                @"hasDetail": @YES,
                @"icon": @"slider.vertical.3",
                @"type": self.typeTextField,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"env_variables",
                @"hasDetail": @YES,
                @"icon": @"terminal",
                @"type": self.typeTextField,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"auto_ram",
                @"hasDetail": @YES,
                @"icon": @"slider.horizontal.3",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame,
                @"warnCondition": ^BOOL(){
                    return !isJailbroken;
                },
                @"warnKey": @"auto_ram_warn",
                @"requestReload": @YES
            },
            @{@"key": @"allocated_memory",
                @"hasDetail": @YES,
                @"icon": @"memorychip",
                @"type": self.typeSlider,
                @"min": @(250),
                @"max": @((NSProcessInfo.processInfo.physicalMemory / 1048576) * 0.85),
                @"enableCondition": ^BOOL(){
                    return ![self.getPreference(@"java", @"auto_ram") boolValue] && whenNotInGame();
                },
                @"warnCondition": ^BOOL(DBNumberedSlider *view){
                    return view.value >= NSProcessInfo.processInfo.physicalMemory / 1048576 * 0.37;
                },
                @"warnKey": @"mem_warn"
            }
        ], @[
            // Debug settings - only recommended for developer use
            @{@"icon": @"ladybug"},
            @{@"key": @"debug_skip_wait_jit",
                @"hasDetail": @YES,
                @"icon": @"forward",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_hide_home_indicator",
                @"hasDetail": @YES,
                @"icon": @"iphone.and.arrow.forward",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return
                        self.splitViewController.view.safeAreaInsets.bottom > 0 ||
                        self.view.safeAreaInsets.bottom > 0;
                }
            },
            @{@"key": @"debug_ipad_ui",
                @"hasDetail": @YES,
                @"icon": @"ipad",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_auto_correction",
                @"hasDetail": @YES,
                @"icon": @"textformat.abc.dottedunderline",
                @"type": self.typeSwitch
            }
        ]
    ];

    [super viewDidLoad];
    if (self.navigationController == nil) {
        self.tableView.alpha = 0.9;
    }
    if (NSProcessInfo.processInfo.isMacCatalystApp) {
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeClose];
        closeButton.frame = CGRectOffset(closeButton.frame, 10, 10);
        [closeButton addTarget:self action:@selector(actionClose) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:closeButton];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController == nil) {
        [self.presentingViewController performSelector:@selector(updatePreferenceChanges)];
    }
}

- (void)actionClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UITableView

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) { // Add to general section
        return [NSString stringWithFormat:@"Angel Aura Amethyst %@-%s (%s/%s)\n%@ on %@ (%s)\nPID: %d",
            NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
            CONFIG_TYPE, CONFIG_BRANCH, CONFIG_COMMIT,
            UIDevice.currentDevice.completeOSVersion, [HostManager GetModelName], getenv("POJAV_DETECTEDINST"), getpid()];
    }

    NSString *footer = NSLocalizedStringWithDefaultValue(([NSString stringWithFormat:@"preference.section.footer.%@", self.prefSections[section]]), @"Localizable", NSBundle.mainBundle, @" ", nil);
    if ([footer isEqualToString:@" "]) {
        return nil;
    }
    return footer;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // First, deselect the row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row + 1];
    NSString *key = item[@"key"];

    // Manual, safe handling for the Mod Settings screen
    if ([key isEqualToString:@"mod_settings"]) {
        ModSettingsViewController *modSettingsVC = [[ModSettingsViewController alloc] init];
        [self.navigationController pushViewController:modSettingsVC animated:YES];
        return; // Explicitly return to prevent superclass interference
    }

    // For all other cells, use the default behavior from the superclass
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end
