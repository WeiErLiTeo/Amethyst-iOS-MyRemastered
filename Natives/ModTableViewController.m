//
//  ModTableViewController.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Updated: removed online-search & open-link, added batch disable/delete, listen to profile change notifications.
//  Fixed compile error by using UIBarButtonItemStylePlain and tintColor for destructive appearance.
//

#import "ModTableViewController.h"
#import "ModItem.h"
#import "ModService.h"
#import "ModTableViewCell.h"

@interface ModTableViewController () <ModTableViewCellDelegate>
@property (nonatomic, strong) NSArray<ModItem *> *mods;
@end

@implementation ModTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Mods";
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.rowHeight = 76;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;

    // Edit button for batch operations
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    // Refresh button (rightmost)
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshTapped)];
    self.navigationItem.rightBarButtonItem = refresh;

    // Observe profile change notifications to reload mods when profile gameDir changed
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(profileDidChange:) name:@"ProfileDidChangeNotification" object:nil];

    [self refreshTapped];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    [self.navigationController setToolbarHidden:!editing animated:YES];

    if (editing) {
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *batchToggle = [[UIBarButtonItem alloc] initWithTitle:@"批量禁用/启用" style:UIBarButtonItemStylePlain target:self action:@selector(batchToggleSelected:)];
        UIBarButtonItem *batchDelete = [[UIBarButtonItem alloc] initWithTitle:@"批量删除" style:UIBarButtonItemStylePlain target:self action:@selector(batchDeleteSelected:)];
        // Use tintColor to indicate destructive
        batchDelete.tintColor = [UIColor systemRedColor];
        self.toolbarItems = @[batchToggle, flex, batchDelete];
    } else {
        self.toolbarItems = nil;
    }
}

- (void)profileDidChange:(NSNotification *)note {
    NSString *profileName = note.userInfo[@"profileName"];
    if (!profileName || [profileName length] == 0) return;
    // If currently viewing the same profile, refresh mods to reflect new gameDir
    if (!self.profileName || [self.profileName isEqualToString:profileName]) {
        [self refreshTapped];
    }
}

- (void)refreshTapped {
    [[ModService sharedService] scanModsForProfile:self.profileName completion:^(NSArray<ModItem *> *mods) {
        self.mods = mods ?: @[];
        [self.tableView reloadData];

        for (NSInteger i = 0; i < self.mods.count; i++) {
            ModItem *m = self.mods[i];
            [[ModService sharedService] fetchMetadataForMod:m completion:^(ModItem *item, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUInteger idx = [self.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj.filePath isEqualToString:item.filePath];
                    }];
                    if (idx != NSNotFound) {
                        NSIndexPath *path = [NSIndexPath indexPathForRow:idx inSection:0];
                        [self.tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
                    }
                });
            }];
        }
    }];
}

#pragma mark - Batch actions

- (NSArray<NSIndexPath *> *)selectedIndexPathsSortedDescending {
    NSArray<NSIndexPath *> *selected = [self.tableView indexPathsForSelectedRows];
    if (!selected) return @[];
    // Sort descending for safe removal
    selected = [selected sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
        if (a.row > b.row) return NSOrderedAscending;
        if (a.row < b.row) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return selected;
}

- (void)batchToggleSelected:(id)sender {
    NSArray<NSIndexPath *> *selected = [self.tableView indexPathsForSelectedRows];
    if (!selected || selected.count == 0) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"提示" message:@"未选择任何模组" preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }
    // Toggle each selected mod
    NSMutableArray<NSIndexPath *> *toReload = [NSMutableArray array];
    for (NSIndexPath *ip in selected) {
        ModItem *m = self.mods[ip.row];
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] toggleEnableForMod:m error:&err];
        if (!ok) {
            NSLog(@"批量切换失败: %@", err.localizedDescription);
        }
        [toReload addObject:ip];
    }
    [self setEditing:NO animated:YES];
    [self.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)batchDeleteSelected:(id)sender {
    NSArray<NSIndexPath *> *selected = [self selectedIndexPathsSortedDescending];
    if (!selected || selected.count == 0) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"提示" message:@"未选择任何模组" preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"确认删除" message:@"确定要删除所选模组吗？此操作不可恢复。" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSMutableArray *newMods = [self.mods mutableCopy];
        NSMutableArray<NSIndexPath *> *deletedIndexPaths = [NSMutableArray array];
        for (NSIndexPath *ip in selected) {
            if (ip.row < newMods.count) {
                ModItem *m = newMods[ip.row];
                NSError *err = nil;
                if ([[ModService sharedService] deleteMod:m error:&err]) {
                    [newMods removeObjectAtIndex:ip.row];
                    [deletedIndexPaths addObject:ip];
                } else {
                    NSLog(@"删除失败: %@", err.localizedDescription);
                }
            }
        }
        self.mods = [newMods copy];
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView endUpdates];
        [self setEditing:NO animated:YES];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Table view data source/delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.mods.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    ModItem *m = self.mods[indexPath.row];
    cell.delegate = self;
    [cell configureWithMod:m];
    return cell;
}

#pragma mark - ModTableViewCellDelegate

- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip) return;
    ModItem *m = self.mods[ip.row];
    NSError *err = nil;
    BOOL ok = [[ModService sharedService] toggleEnableForMod:m error:&err];
    if (!ok) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
    } else {
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip) return;
    ModItem *m = self.mods[ip.row];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"确认删除" message:m.displayName preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSError *err = nil;
        if ([[ModService sharedService] deleteMod:m error:&err]) {
            NSMutableArray *new = [self.mods mutableCopy];
            [new removeObjectAtIndex:ip.row];
            self.mods = [new copy];
            [self.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"删除失败" message:err.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [errAc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:errAc animated:YES completion:nil];
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end