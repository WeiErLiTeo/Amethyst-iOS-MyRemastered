//
//  ModTableViewController.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//

#import "ModTableViewController.h"
#import "ModService.h"
#import "ModItem.h"
#import "ModTableViewCell.h"

@interface ModTableViewController () <ModTableViewCellDelegate>

@property (nonatomic, strong) NSMutableArray<ModItem *> *mods;

@end

@implementation ModTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Mods";
    self.mods = [NSMutableArray array];
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.rowHeight = 76;
    self.tableView.tableFooterView = [UIView new];

    // initial scan
    [self reloadMods];

    // optionally add pull to refresh
    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(reloadMods) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = rc;
}

- (void)reloadMods {
    NSString *profile = self.profileName ?: @"default";
    [[ModService sharedService] scanModsForProfile:profile completion:^(NSArray<ModItem *> *mods) {
        // ensure UI update on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mods removeAllObjects];
            [self.mods addObjectsFromArray:mods];
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    ModItem *m = self.mods[indexPath.row];
    [cell configureWithMod:m];
    cell.delegate = self;

    // lazy-load metadata (if not already filled)
    if ((!m.modDescription || m.modDescription.length == 0) || (!m.iconURL || m.iconURL.length == 0)) {
        [[ModService sharedService] fetchMetadataForMod:m completion:^(ModItem *item, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // reload the specific row if still visible
                NSUInteger idx = [self.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.filePath isEqualToString:item.filePath];
                }];
                if (idx != NSNotFound) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:idx inSection:0];
                    [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
                }
            });
        }];
    }

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
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"无法切换 mod 状态" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        });
    } else {
        // update cell UI
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip) return;
    ModItem *m = self.mods[ip.row];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"删除 Mod" message:[NSString stringWithFormat:@"确定删除 %@ ?", m.displayName ?: m.fileName] preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] deleteMod:m error:&err];
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"删除失败" preferredStyle:UIAlertControllerStyleAlert];
                [errAc addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errAc animated:YES completion:nil];
            });
        } else {
            // remove from list and update UI
            [self.mods removeObjectAtIndex:ip.row];
            [self.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    // for iPad present properly
    UIPopoverPresentationController *pp = ac.popoverPresentationController;
    if (pp && cell) {
        pp.sourceView = cell;
        pp.sourceRect = cell.bounds;
    }
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Table editing (swipe to delete)

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        ModItem *m = self.mods[indexPath.row];
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] deleteMod:m error:&err];
        if (!ok) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"错误" message:err.localizedDescription ?: @"删除失败" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        } else {
            [self.mods removeObjectAtIndex:indexPath.row];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end