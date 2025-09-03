#import "ModsManagerViewController.h"
#import "ModTableViewCell.h"
#import "ModService.h"

@interface ModsManagerViewController () <UITableViewDataSource, UITableViewDelegate, ModTableViewCellDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<ModItem *> *mods;
@end

@implementation ModsManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"管理 Mod";

    // 添加“批量”按钮
    UIBarButtonItem *batchButton = [[UIBarButtonItem alloc] initWithTitle:@"批量"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(batchAction)];
    self.navigationItem.rightBarButtonItem = batchButton;

    [self setupTableView];
    [self loadMods];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    [self.view addSubview:self.tableView];
}

- (void)loadMods {
    [[ModService sharedService] scanModsForProfile:self.profileName completion:^(NSArray<ModItem *> *mods) {
        self.mods = mods;
        [self.tableView reloadData];
    }];
}

// 批量操作逻辑
- (void)batchAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"批量操作"
                                                                   message:@"请选择操作类型"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"启用所有 Mod" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self toggleAllMods:NO];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"禁用所有 Mod" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self toggleAllMods:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleAllMods:(BOOL)disable {
    for (ModItem *mod in self.mods) {
        if (mod.disabled != disable) {
            NSError *error = nil;
            [[ModService sharedService] toggleEnableForMod:mod error:&error];
            if (error) {
                NSLog(@"无法切换 Mod 状态: %@", error.localizedDescription);
            }
        }
    }
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    [cell configureWithMod:self.mods[indexPath.row]];
    cell.delegate = self;
    return cell;
}

#pragma mark - ModTableViewCellDelegate

- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    ModItem *mod = self.mods[indexPath.row];
    NSError *error = nil;
    if ([[ModService sharedService] toggleEnableForMod:mod error:&error]) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        NSLog(@"无法切换 Mod 状态: %@", error.localizedDescription);
    }
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    ModItem *mod = self.mods[indexPath.row];
    NSError *error = nil;
    if ([[ModService sharedService] deleteMod:mod error:&error]) {
        NSMutableArray *mutableMods = [self.mods mutableCopy];
        [mutableMods removeObjectAtIndex:indexPath.row];
        self.mods = mutableMods;
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        NSLog(@"无法删除 Mod: %@", error.localizedDescription);
    }
}

@end