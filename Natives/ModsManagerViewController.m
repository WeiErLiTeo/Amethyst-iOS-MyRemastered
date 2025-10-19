#import "ModsManagerViewController.h"
#import "ModTableViewCell.h"
#import "ModService.h"
#import "ModItem.h"
#import "installer/modpack/ModrinthAPI.h"

@interface ModsManagerViewController () <UITableViewDataSource, UITableViewDelegate, ModTableViewCellDelegate, UISearchBarDelegate, ModVersionViewControllerDelegate>

// ... (all existing properties are the same)
@property (nonatomic, strong) UISegmentedControl *modeSwitcher;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIBarButtonItem *batchButton;
@property (nonatomic, strong) UIBarButtonItem *refreshButton;
@property (nonatomic, strong) NSMutableArray<ModItem *> *localMods;
@property (nonatomic, strong) NSMutableArray<ModItem *> *filteredLocalMods;

@end

@implementation ModsManagerViewController

// ... (viewDidLoad, setupUI, modeChanged, updateUIForCurrentMode, updateNavigationButtons are the same)

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"管理 Mod";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.currentMode = ModsManagerModeLocal;
    self.isBatchMode = NO;
    self.localMods = [NSMutableArray array];
    self.filteredLocalMods = [NSMutableArray array];
    self.onlineSearchResults = [NSMutableArray array];
    self.selectedModPaths = [NSMutableSet set];
    [self setupUI];
    [self refreshLocalModsList];
}

- (void)setupUI {
    self.modeSwitcher = [[UISegmentedControl alloc] initWithItems:@[@"本地 Mod", @"在线搜索 (Modrinth)"]];
    self.modeSwitcher.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSwitcher.selectedSegmentIndex = 0;
    [self.modeSwitcher addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeSwitcher];
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索本地 Mod...";
    [self.view addSubview:self.searchBar];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 100;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];
    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(refreshLocalModsList) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = rc;
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshLocalModsList)];
    self.batchButton = [[UIBarButtonItem alloc] initWithTitle:@"批量" style:UIBarButtonItemStylePlain target:self action:@selector(toggleBatchMode)];
    [self updateNavigationButtons];
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSwitcher.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.modeSwitcher.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.modeSwitcher.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.searchBar.topAnchor constraintEqualToAnchor:self.modeSwitcher.bottomAnchor constant:8],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor]
    ]];
}

- (void)modeChanged:(UISegmentedControl *)sender {
    self.currentMode = (ModsManagerMode)sender.selectedSegmentIndex;
    [self.searchBar resignFirstResponder];
    self.searchBar.text = @"";
    [self.onlineSearchResults removeAllObjects];
    [self filterLocalMods];
    [self.tableView reloadData];
    [self updateUIForCurrentMode];
}

- (void)updateUIForCurrentMode {
    if (self.currentMode == ModsManagerModeLocal) {
        self.searchBar.placeholder = @"搜索本地 Mod...";
        self.tableView.refreshControl.enabled = YES;
        self.emptyLabel.text = @"未发现 Mod";
        self.emptyLabel.hidden = self.localMods.count > 0;
    } else {
        self.searchBar.placeholder = @"在线搜索 Modrinth...";
        self.tableView.refreshControl.enabled = NO;
        self.emptyLabel.text = @"输入关键词进行在线搜索";
        self.emptyLabel.hidden = self.onlineSearchResults.count > 0;
    }
    [self updateNavigationButtons];
    [self.tableView reloadData];
}

- (void)updateNavigationButtons {
    if (self.currentMode == ModsManagerModeLocal) {
        if (self.isBatchMode) {
            self.batchButton = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(toggleBatchMode)];
            UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelectedMods)];
            self.navigationItem.rightBarButtonItems = @[self.batchButton, deleteButton];
        } else {
            self.batchButton = [[UIBarButtonItem alloc] initWithTitle:@"批量" style:UIBarButtonItemStylePlain target:self action:@selector(toggleBatchMode)];
            self.navigationItem.rightBarButtonItems = @[self.refreshButton, self.batchButton];
        }
    } else {
        self.navigationItem.rightBarButtonItems = nil;
    }
}

#pragma mark - Data Loading

- (void)setLoading:(BOOL)loading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            self.emptyLabel.hidden = YES;
            [self.activityIndicator startAnimating];
        } else {
            [self.activityIndicator stopAnimating];
            [self.tableView.refreshControl endRefreshing];
        }
    });
}

- (void)refreshLocalModsList {
    if (self.currentMode != ModsManagerModeLocal) return;

    [self setLoading:YES];
    NSString *profile = self.profileName ?: @"default";
    [[ModService sharedService] scanModsForProfile:profile completion:^(NSArray<ModItem *> *mods) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.localMods removeAllObjects];
            [self.localMods addObjectsFromArray:mods];
            [self filterLocalMods];
            [self setLoading:NO];
        });
    }];
}

- (void)performOnlineSearch {
    NSString *searchText = self.searchBar.text;
    if (searchText.length == 0) return;

    [self setLoading:YES];
    [self.onlineSearchResults removeAllObjects];
    [self.tableView reloadData];

    NSDictionary *filters = @{@"name": searchText};

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *modrinthResults = [[ModrinthAPI sharedInstance] searchModWithFilters:filters previousPageResult:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (modrinthResults) {
                [self.onlineSearchResults addObjectsFromArray:modrinthResults];
            }
            [self setLoading:NO];
            self.emptyLabel.hidden = self.onlineSearchResults.count > 0;
            if (self.onlineSearchResults.count == 0) {
                self.emptyLabel.text = @"未找到在线结果";
            }
            [self.tableView reloadData];
        });
    });
}


#pragma mark - UISearchBarDelegate
// ... (search bar delegate methods are the same)
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (self.currentMode == ModsManagerModeLocal) {
        [self filterLocalMods];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if (self.currentMode == ModsManagerModeOnline) {
        [self performOnlineSearch];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    if (self.currentMode == ModsManagerModeLocal) {
        [self filterLocalMods];
    } else {
        [self.onlineSearchResults removeAllObjects];
        [self.tableView reloadData];
        [self updateUIForCurrentMode];
    }
}

- (void)filterLocalMods {
    [self.filteredLocalMods removeAllObjects];
    if (self.searchBar.text.length == 0) {
        [self.filteredLocalMods addObjectsFromArray:self.localMods];
    } else {
        NSString *searchText = [self.searchBar.text lowercaseString];
        for (ModItem *mod in self.localMods) {
            if ([mod.displayName.lowercaseString containsString:searchText] ||
                [mod.fileName.lowercaseString containsString:searchText]) {
                [self.filteredLocalMods addObject:mod];
            }
        }
    }
    self.emptyLabel.hidden = self.filteredLocalMods.count > 0;
    if (!self.emptyLabel.hidden) {
        self.emptyLabel.text = @"未找到本地 Mod";
    }
    [self.tableView reloadData];
}

#pragma mark - UITableView DataSource & Delegate
// ... (UITableView methods are the same)
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentMode == ModsManagerModeLocal ? self.filteredLocalMods.count : self.onlineSearchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    cell.delegate = self;

    if (self.currentMode == ModsManagerModeLocal) {
        ModItem *mod = self.filteredLocalMods[indexPath.row];
        [cell configureWithMod:mod displayMode:ModTableViewCellDisplayModeLocal];
        [cell updateBatchSelectionState:[self.selectedModPaths containsObject:mod.filePath] batchMode:self.isBatchMode];
    } else {
        NSDictionary *modData = self.onlineSearchResults[indexPath.row];
        ModItem *modItem = [[ModItem alloc] initWithOnlineData:modData];
        [cell configureWithMod:modItem displayMode:ModTableViewCellDisplayModeOnline];
    }

    return cell;
}


#pragma mark - ModTableViewCellDelegate (Download Implementation)

- (void)modCellDidTapDownload:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath || self.currentMode != ModsManagerModeOnline) return;

    NSDictionary *modData = self.onlineSearchResults[indexPath.row];
    ModItem *modItem = [[ModItem alloc] initWithOnlineData:modData];
    
    ModVersionViewController *versionVC = [[ModVersionViewController alloc] init];
    versionVC.modItem = modItem;
    versionVC.delegate = self;
    
    [self.navigationController pushViewController:versionVC animated:YES];
}

#pragma mark - ModVersionViewControllerDelegate

- (void)modVersionViewController:(ModVersionViewController *)viewController didSelectVersion:(ModVersion *)version {
    ModItem *itemToDownload = viewController.modItem;
    
    // Find the primary file to download
    NSDictionary *primaryFile = version.primaryFile;
    if (!primaryFile || ![primaryFile[@"url"] isKindOfClass:[NSString class]]) {
        [self showSimpleAlertWithTitle:@"错误" message:@"未找到有效的下载链接。"];
        return;
    }

    itemToDownload.selectedVersionDownloadURL = primaryFile[@"url"];
    itemToDownload.fileName = primaryFile[@"filename"];

    [self startDownloadForItem:itemToDownload];
}

- (void)startDownloadForItem:(ModItem *)item {
    [self showSimpleAlertWithTitle:@"下载开始" message:[NSString stringWithFormat:@"正在下载 %@...", item.displayName]];

    [[ModService sharedService] downloadMod:item toProfile:self.profileName completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showSimpleAlertWithTitle:@"下载失败" message:error.localizedDescription];
            } else {
                [self showSimpleAlertWithTitle:@"下载成功" message:[NSString stringWithFormat:@"%@ 已成功安装。", item.displayName]];
                // Optionally, switch to local mods and refresh
                // [self.modeSwitcher setSelectedSegmentIndex:0];
                // [self modeChanged:self.modeSwitcher];
                // [self refreshLocalModsList];
            }
        });
    }];
}

- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)toggleBatchMode {
    if (self.currentMode != ModsManagerModeLocal) return;
    self.isBatchMode = !self.isBatchMode;
    if (!self.isBatchMode) {
        [self.selectedModPaths removeAllObjects];
    }
    [self updateNavigationButtons];
    [self.tableView reloadData];
}

- (void)deleteSelectedMods {
    if (self.selectedModPaths.count == 0) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除" message:[NSString stringWithFormat:@"确定要删除 %lu 个 Mod 吗？此操作无法撤销。", (unsigned long)self.selectedModPaths.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        for (NSString *path in self.selectedModPaths) {
            ModItem *itemToDelete = nil;
            for (ModItem *item in self.localMods) {
                if ([item.filePath isEqualToString:path]) {
                    itemToDelete = item;
                    break;
                }
            }
            if (itemToDelete) {
                [[ModService sharedService] deleteMod:itemToDelete error:nil];
            }
        }
        [self.selectedModPaths removeAllObjects];
        [self refreshLocalModsList];
        // Exit batch mode after deletion
        self.isBatchMode = NO;
        [self updateNavigationButtons];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    if (self.currentMode != ModsManagerModeLocal) return;
    // ... (logic for single delete)
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentMode == ModsManagerModeLocal && self.isBatchMode) {
        ModItem *mod = self.filteredLocalMods[indexPath.row];
        if ([self.selectedModPaths containsObject:mod.filePath]) {
            [self.selectedModPaths removeObject:mod.filePath];
        } else {
            [self.selectedModPaths addObject:mod.filePath];
        }
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    } else if (self.currentMode == ModsManagerModeOnline) {
        // Handle online search item selection if necessary (e.g., show details)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

// Stub implementations for unused delegate methods to silence warnings
- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    // Not used in this controller in local mode, but required by protocol.
}
- (void)modCellDidTapOpenLink:(UITableViewCell *)cell {
    // Not used in this controller, but required by protocol.
}

@end
