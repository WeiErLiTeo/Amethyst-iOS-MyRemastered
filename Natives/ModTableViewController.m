//
//  ModTableViewController.m
//  AmethystMods
//
//  Created by Copilot on 2025-08-22.
//  Implements the mods list, refresh button and the "上网搜索" toggle.
//

#import "ModTableViewController.h"
#import "ModItem.h"
#import "ModService.h"
#import "ModTableViewCell.h"

@interface ModTableViewController () <ModTableViewCellDelegate>
@property (nonatomic, strong) NSArray<ModItem *> *mods;
@property (nonatomic, strong) UISwitch *onlineSearchSwitch;
@end

@implementation ModTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Mods";
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.rowHeight = 76;

    // 在线搜索开关（放在导航栏右侧，靠近刷新）
    self.onlineSearchSwitch = [[UISwitch alloc] init];
    self.onlineSearchSwitch.on = [ModService sharedService].onlineSearchEnabled;
    [self.onlineSearchSwitch addTarget:self action:@selector(toggleOnlineSearch:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *switchItem = [[UIBarButtonItem alloc] initWithCustomView:self.onlineSearchSwitch];

    // label 说明 (右侧)
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithTitle:@"上网搜索" style:UIBarButtonItemStylePlain target:nil action:nil];
    labelItem.enabled = NO;

    // 刷新按钮
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshTapped)];

    // 将 switch 和 label 放在刷新左侧
    self.navigationItem.rightBarButtonItems = @[refresh, switchItem, labelItem];

    [self refreshTapped];
}

- (void)toggleOnlineSearch:(UISwitch *)sw {
    [ModService sharedService].onlineSearchEnabled = sw.isOn;
    // 小提示：可以重新刷新以便使用在线数据
    [self refreshTapped];
}

- (void)refreshTapped {
    // 重新扫描 mod 文件夹
    [[ModService sharedService] scanModsForProfile:self.profileName completion:^(NSArray<ModItem *> *mods) {
        self.mods = mods;
        [self.tableView reloadData];
        // 对每个 mod 异步获取 metadata（如果需要）
        for (NSInteger i = 0; i < mods.count; i++) {
            ModItem *m = mods[i];
            [[ModService sharedService] fetchMetadataForMod:m completion:^(ModItem *item, NSError * _Nullable error) {
                // 更新数组并刷新对应行
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUInteger idx = [self.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj.filePath isEqualToString:item.filePath];
                    }];
                    if (idx != NSNotFound) {
                        NSIndexPath *path = [NSIndexPath indexPathForRow:idx inSection:0];
                        [self.tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
                    } else {
                        [self.tableView reloadData];
                    }
                });
            }];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mods.count;
}
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

- (void)modCellDidTapOpenLink:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip) return;
    ModItem *m = self.mods[ip.row];
    NSString *urlStr = m.homepage.length ? m.homepage : (m.sources.length ? m.sources : nil);
    if (!urlStr) return;
    NSURL *u = [NSURL URLWithString:urlStr];
    if (!u) {
        // try adding scheme if missing
        NSString *withScheme = [NSString stringWithFormat:@"https://%@", urlStr];
        u = [NSURL URLWithString:withScheme];
    }
    if (u) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
        });
    }
}

@end