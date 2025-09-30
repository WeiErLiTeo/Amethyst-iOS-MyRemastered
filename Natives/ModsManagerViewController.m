//
// ModsManagerViewController.m
// AmethystMods
//
// Created by Copilot (adjusted) on 2025-08-22.
// Revised: add profileName handling and robust UI/data updates.
//

#import "ModsManagerViewController.h"
#import "ModTableViewCell.h"
#import "ModService.h"
#import "ModItem.h"

@interface ModsManagerViewController () <UITableViewDataSource, UITableViewDelegate, ModTableViewCellDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ModItem *> *mods;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIBarButtonItem *batchButton;
@property (nonatomic, strong) UIBarButtonItem *refreshButton;
@property (nonatomic, strong) UIToolbar *bottomToolbar;
@property (nonatomic, strong) UIBarButtonItem *batchDisableButton;
@property (nonatomic, strong) UIBarButtonItem *batchDeleteButton;
@property (nonatomic, strong) UIBarButtonItem *selectAllButton;
@property (nonatomic, strong) UIBarButtonItem *flexibleSpace;
@property (nonatomic, strong) UIBarButtonItem *fixedSpace;

@end

@implementation ModsManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"管理 Mod";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Initialize batch mode properties
    self.isBatchMode = NO;
    self.selectedModPaths = [NSMutableSet set];

    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];

    // Refresh control
    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(refreshList) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = rc;

    // Activity indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    // Empty label
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"未发现 Mod";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    // Toolbar buttons
    self.batchDisableButton = [[UIBarButtonItem alloc] initWithTitle:@"批量禁用" style:UIBarButtonItemStylePlain target:self action:@selector(batchDisable)];
    self.batchDeleteButton = [[UIBarButtonItem alloc] initWithTitle:@"批量删除" style:UIBarButtonItemStylePlain target:self action:@selector(batchDelete)];
    self.selectAllButton = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllMods)];
    self.flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    self.fixedSpace.width = 20;

    // Bottom toolbar
    self.bottomToolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    self.bottomToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomToolbar.hidden = YES;
    [self.view addSubview:self.bottomToolbar];

    // Navigation item buttons
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshList)];
    self.batchButton = [[UIBarButtonItem alloc] initWithTitle:@"批量" style:UIBarButtonItemStylePlain target:self action:@selector(toggleBatchMode)];
    self.navigationItem.rightBarButtonItems = @[self.refreshButton, self.batchButton];

    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.bottomToolbar.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.bottomToolbar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomToolbar.heightAnchor constraintEqualToConstant:44]
    ]];

    // Initialize data
    self.mods = [NSMutableArray array];
    
    // Initialize batch button states
    [self updateBatchButtonStates];

    // Initial load
    [self refreshList];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Refresh list when view appears to pick up external changes
    [self refreshList];
    
    // Update batch mode UI
    [self updateBatchModeUI];
}

#pragma mark - Loading

- (void)setLoading:(BOOL)loading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            [self.activityIndicator startAnimating];
        } else {
            [self.activityIndicator stopAnimating];
            [self.tableView.refreshControl endRefreshing];
        }
    });
}

- (void)refreshList {
    [self setLoading:YES];
    __weak typeof(self) weakSelf = self;
    NSString *profile = self.profileName ?: @"default";
    [[ModService sharedService] scanModsForProfile:profile completion:^(NSArray<ModItem *> *mods) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // Update UI on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.mods removeAllObjects];
            if (mods.count > 0) {
                [strongSelf.mods addObjectsFromArray:mods];
                strongSelf.emptyLabel.hidden = YES;
            } else {
                strongSelf.emptyLabel.hidden = NO;
            }
            [strongSelf.tableView reloadData];
            [strongSelf setLoading:NO];
        });

        // Fetch metadata for each mod to fill details asynchronously
        for (ModItem *m in mods) {
            [[ModService sharedService] fetchMetadataForMod:m completion:^(ModItem *item, NSError * _Nullable error) {
                __strong typeof(weakSelf) ss = weakSelf;
                if (!ss) return;
                NSUInteger idx = [ss.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.filePath isEqualToString:item.filePath];
                }];
                if (idx != NSNotFound) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (idx < ss.mods.count) {
                            ModItem *stored = ss.mods[idx];
                            stored.displayName = item.displayName ?: stored.displayName;
                            stored.modDescription = item.modDescription ?: stored.modDescription;
                            stored.iconURL = item.iconURL ?: stored.iconURL;
                            stored.fileSHA1 = item.fileSHA1 ?: stored.fileSHA1;
                            stored.version = item.version ?: stored.version;
                            stored.homepage = item.homepage ?: stored.homepage;
                            stored.isFabric = item.isFabric;
                            stored.isForge = item.isForge;
                            stored.isNeoForge = item.isNeoForge;
                            [ss.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                        }
                    });
                }
            }];
        }
    }];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    ModItem *m = nil;
    if ((NSUInteger)indexPath.row < self.mods.count) {
        m = self.mods[indexPath.row];
    }
    cell.delegate = self;
    if (m) {
        [cell configureWithMod:m];
        // Set batch mode and selection state
        [cell updateBatchSelectionState:[self.selectedModPaths containsObject:m.filePath] batchMode:self.isBatchMode];
    } else {
        // Defensive: create an empty placeholder ModItem if out-of-range
        [cell configureWithMod:[[ModItem alloc] initWithFilePath:@""]];
        [cell updateBatchSelectionState:NO batchMode:self.isBatchMode];
    }
    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isBatchMode) {
        if ((NSUInteger)indexPath.row < self.mods.count) {
            ModItem *mod = self.mods[indexPath.row];
            [self toggleModSelection:mod.filePath];
            // Update batch button states
            [self updateBatchButtonStates];
            
            // Update the cell's selection state directly instead of reloading
            ModTableViewCell *cell = (ModTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                [cell updateBatchSelectionState:[self.selectedModPaths containsObject:mod.filePath] batchMode:self.isBatchMode];
            }
        }
    }
}

#pragma mark - Batch Operations

- (void)toggleBatchMode {
    self.isBatchMode = !self.isBatchMode;
    [self updateBatchModeUI];
    [self.tableView reloadData];
    
    // 确保在退出批量模式时清除所有选择
    if (!self.isBatchMode) {
        [self.selectedModPaths removeAllObjects];
        // 修复：确保退出批量模式后按钮状态正确更新
        [self updateBatchButtonStates];
    }
}

- (void)updateBatchModeUI {
    if (self.isBatchMode) {
        self.batchButton.title = @"取消";
        // 在批量模式下，将批量操作按钮放在导航栏右侧
        self.navigationItem.rightBarButtonItems = @[self.batchDeleteButton, self.batchDisableButton, self.selectAllButton, self.batchButton];
        self.bottomToolbar.hidden = YES;
        
        // Clear selection when entering batch mode
        [self.selectedModPaths removeAllObjects];
    } else {
        self.batchButton.title = @"批量";
        self.navigationItem.rightBarButtonItems = @[self.refreshButton, self.batchButton];
        self.bottomToolbar.hidden = YES;
        [self.selectedModPaths removeAllObjects];
        
        // 退出批量模式时，刷新表格以确保所有单元格正确更新
        [self.tableView reloadData];
    }
    
    // Update batch button states
    [self updateBatchButtonStates];
}

- (void)toggleModSelection:(NSString *)modPath {
    if ([self.selectedModPaths containsObject:modPath]) {
        [self.selectedModPaths removeObject:modPath];
    } else {
        [self.selectedModPaths addObject:modPath];
    }
    
    // Update batch button states
    [self updateBatchButtonStates];
}

- (void)updateBatchButtonStates {
    BOOL hasSelection = self.selectedModPaths.count > 0;
    self.batchDisableButton.enabled = hasSelection;
    self.batchDeleteButton.enabled = hasSelection;
}

- (void)selectAllMods {
    // Clear current selection
    [self.selectedModPaths removeAllObjects];
    
    // Select all mods
    for (ModItem *mod in self.mods) {
        [self.selectedModPaths addObject:mod.filePath];
    }
    
    // Update UI
    [self.tableView reloadData];
    [self updateBatchButtonStates];
}

- (void)batchDisable {
    if (self.selectedModPaths.count == 0) return;
    
    NSString *title = @"批量禁用 Mod";
    NSString *message = [NSString stringWithFormat:@"确定禁用这 %lu 个 Mod 吗？", (unsigned long)self.selectedModPaths.count];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf performBatchDisable];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)performBatchOperationWithAction:(void (^)(ModItem *))action {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<ModItem *> *modsToProcess = [NSMutableArray array];
        
        // Find mods to process
        for (ModItem *mod in weakSelf.mods) {
            if ([weakSelf.selectedModPaths containsObject:mod.filePath]) {
                [modsToProcess addObject:mod];
            }
        }
        
        // Process each mod
        for (ModItem *mod in modsToProcess) {
            action(mod);
        }
        
        // Update UI on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Update the specific rows instead of refreshing the entire list
            for (ModItem *mod in modsToProcess) {
                NSUInteger idx = [strongSelf.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.filePath isEqualToString:mod.filePath];
                }];
                if (idx != NSNotFound && idx < strongSelf.mods.count) {
                    // Update the mod item's properties (they are updated in-place by toggleEnableForMod)
                    [mod refreshDisabledFlag];
                    
                    // Update the cell's UI directly without reloading metadata
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
                    ModTableViewCell *cell = (ModTableViewCell *)[strongSelf.tableView cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        [cell updateToggleState:mod.disabled];
                    }
                }
            }
            
            // Exit batch mode
            strongSelf.isBatchMode = NO;
            [strongSelf updateBatchModeUI];
            
            // Clear selection after batch operation
            [strongSelf.selectedModPaths removeAllObjects];
            
            // 修复：确保批量操作后按钮状态正确更新
            [strongSelf updateBatchButtonStates];
        });
    });
}

- (void)performBatchDisable {
    [self performBatchOperationWithAction:^(ModItem *mod) {
        NSError *error = nil;
        [[ModService sharedService] toggleEnableForMod:mod error:&error];
    }];
}

- (void)batchDelete {
    if (self.selectedModPaths.count == 0) return;
    
    NSString *title = @"批量删除 Mod";
    NSString *message = [NSString stringWithFormat:@"确认删除这 %lu 个 Mod 文件吗？此操作不可撤销。", (unsigned long)self.selectedModPaths.count];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf performBatchDelete];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)performBatchDelete {
    [self performBatchOperationWithAction:^(ModItem *mod) {
        NSError *error = nil;
        [[ModService sharedService] deleteMod:mod error:&error];
    }];
}

#pragma mark - ModTableViewCellDelegate

- (void)modCellDidTapOpenLink:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip || (NSUInteger)ip.row >= self.mods.count) return;
    ModItem *mod = self.mods[ip.row];
    
    NSURL *url = nil;
    if (mod.homepage && mod.homepage.length > 0) {
        url = [NSURL URLWithString:mod.homepage];
    }
    
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无链接" message:@"此Mod没有提供主页或源代码链接。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip || (NSUInteger)ip.row >= self.mods.count) return;
    ModItem *mod = self.mods[ip.row];
    
    // In batch mode, toggle selection instead of enabling/disabling
    if (self.isBatchMode) {
        [self toggleModSelection:mod.filePath];
        // Update the cell's selection state directly instead of reloading
        ModTableViewCell *modCell = (ModTableViewCell *)cell;
        [modCell updateBatchSelectionState:[self.selectedModPaths containsObject:mod.filePath] batchMode:self.isBatchMode];
        return;
    }
    
    NSString *title = mod.disabled ? @"启用 Mod" : @"禁用 Mod";
    NSString *message = mod.disabled ? @"确定启用此 Mod 吗？" : @"确定禁用此 Mod 吗？";
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] toggleEnableForMod:mod error:&err];
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"操作失败" preferredStyle:UIAlertControllerStyleAlert];
                [errAc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:errAc animated:YES completion:nil];
            });
        } else {
            // Instead of refreshing the entire list, just update the specific row
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update the mod item's properties (they are updated in-place by toggleEnableForMod)
                [mod refreshDisabledFlag];
                
                // Update the cell's UI directly without reloading metadata
                ModTableViewCell *modCell = (ModTableViewCell *)cell;
                [modCell updateToggleState:mod.disabled];
            });
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip || (NSUInteger)ip.row >= self.mods.count) return;
    ModItem *mod = self.mods[ip.row];
    
    // In batch mode, toggle selection instead of deleting
    if (self.isBatchMode) {
        [self toggleModSelection:mod.filePath];
        // Update the cell's selection state directly instead of reloading
        ModTableViewCell *modCell = (ModTableViewCell *)cell;
        [modCell updateBatchSelectionState:[self.selectedModPaths containsObject:mod.filePath] batchMode:self.isBatchMode];
        return;
    }
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"删除 Mod" message:@"确认删除此 Mod 文件吗？此操作不可撤销。" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] deleteMod:mod error:&err];
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"删除失败" preferredStyle:UIAlertControllerStyleAlert];
                [errAc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:errAc animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ((NSUInteger)ip.row < strongSelf.mods.count) {
                    [strongSelf.mods removeObjectAtIndex:ip.row];
                    [strongSelf.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
                    strongSelf.emptyLabel.hidden = (strongSelf.mods.count != 0);
                } else {
                    [strongSelf refreshList];
                }
            });
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Table editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if ((NSUInteger)indexPath.row >= self.mods.count) return;
        ModItem *m = self.mods[indexPath.row];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            BOOL ok = [[ModService sharedService] deleteMod:m error:&err];
            __strong typeof(weakSelf) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!strongSelf) return;
                if (!ok) {
                    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"删除失败" preferredStyle:UIAlertControllerStyleAlert];
                    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                    [strongSelf presentViewController:ac animated:YES completion:nil];
                } else {
                    if ((NSUInteger)indexPath.row < strongSelf.mods.count) {
                        [strongSelf.mods removeObjectAtIndex:indexPath.row];
                        [strongSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        strongSelf.emptyLabel.hidden = (strongSelf.mods.count != 0);
                    } else {
                        [strongSelf refreshList];
                    }
                }
            });
        });
    }
}

@end
