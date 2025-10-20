#import "ModVersionViewController.h"
#import "installer/modpack/ModrinthAPI.h"
#import "ModVersion.h"
#import "ModVersionTableViewCell.h"

@interface ModVersionViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *gameVersionFilterButton;
@property (nonatomic, strong) UIButton *loaderFilterButton;

@property (nonatomic, strong) NSArray<ModVersion *> *allVersions;
@property (nonatomic, strong) NSArray<ModVersion *> *filteredVersions;

@property (nonatomic, strong) NSArray<NSString *> *availableGameVersions;
@property (nonatomic, strong) NSArray<NSString *> *availableLoaders;

@property (nonatomic, strong) NSString *selectedGameVersion;
@property (nonatomic, strong) NSString *selectedLoader;

@end

@implementation ModVersionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.modItem.displayName;
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupFilterControls];
    [self setupTableView];
    [self setupActivityIndicator];

    [self fetchVersions];
}

- (void)setupFilterControls {
    // Labels
    UILabel *gameVersionLabel = [self createFilterLabelWithText:@"游戏版本:"];
    UILabel *loaderLabel = [self createFilterLabelWithText:@"加载器:"];

    // Buttons
    self.gameVersionFilterButton = [self createFilterButtonWithTitle:@"加载中..."];
    self.loaderFilterButton = [self createFilterButtonWithTitle:@"加载中..."];

    // Horizontal Stack for Game Version
    UIStackView *gameVersionStack = [[UIStackView alloc] initWithArrangedSubviews:@[gameVersionLabel, self.gameVersionFilterButton]];
    gameVersionStack.axis = UILayoutConstraintAxisHorizontal;
    gameVersionStack.spacing = 8;
    gameVersionStack.alignment = UIStackViewAlignmentCenter;

    // Horizontal Stack for Loader
    UIStackView *loaderStack = [[UIStackView alloc] initWithArrangedSubviews:@[loaderLabel, self.loaderFilterButton]];
    loaderStack.axis = UILayoutConstraintAxisHorizontal;
    loaderStack.spacing = 8;
    loaderStack.alignment = UIStackViewAlignmentCenter;

    // Main Vertical Stack
    UIStackView *mainFilterStack = [[UIStackView alloc] initWithArrangedSubviews:@[gameVersionStack, loaderStack]];
    mainFilterStack.translatesAutoresizingMaskIntoConstraints = NO;
    mainFilterStack.axis = UILayoutConstraintAxisVertical;
    mainFilterStack.spacing = 8;
    mainFilterStack.alignment = UIStackViewAlignmentLeading;

    [self.view addSubview:mainFilterStack];

    [NSLayoutConstraint activateConstraints:@[
        [mainFilterStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [mainFilterStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [mainFilterStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-16],

        // Ensure labels don't get overly compressed
        [gameVersionLabel.widthAnchor constraintEqualToConstant:80],
        [loaderLabel.widthAnchor constraintEqualToConstant:80]
    ]];
}

- (UILabel *)createFilterLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = [UIColor labelColor];
    label.font = [UIFont systemFontOfSize:16];
    return label;
}

- (UIButton *)createFilterButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.layer.cornerRadius = 8;
    // Set a minimum width to prevent the button from being too small
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10); // Add some padding
    button.backgroundColor = [UIColor secondarySystemBackgroundColor];
    button.showsMenuAsPrimaryAction = YES;
    return button;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[ModVersionTableViewCell class] forCellReuseIdentifier:@"ModVersionCell"];
    [self.view addSubview:self.tableView];

    // Find the stack view to constrain the table view against
    UIView *filterStackView = self.gameVersionFilterButton.superview;

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:filterStackView.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupActivityIndicator {
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)fetchVersions {
    [self.activityIndicator startAnimating];
    [[ModrinthAPI sharedInstance] getVersionsForModWithID:self.modItem.onlineID completion:^(NSArray<ModVersion *> * _Nullable versions, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            if (error) {
                NSLog(@"Error fetching versions: %@", error);
                // Handle error
                return;
            }
            self.allVersions = versions;
            [self processFilters];
            [self filterChanged];
        });
    }];
}

- (void)processFilters {
    NSMutableSet<NSString *> *gameVersions = [NSMutableSet setWithObject:@"全部"];
    NSMutableSet<NSString *> *loaders = [NSMutableSet setWithObject:@"全部"];

    for (ModVersion *version in self.allVersions) {
        for (NSString *gameVersion in version.gameVersions) {
            [gameVersions addObject:gameVersion];
        }
        for (NSString *loader in version.loaders) {
            [loaders addObject:[loader capitalizedString]]; // Capitalize for display
        }
    }

    // Sort game versions with semantic versioning
    self.availableGameVersions = [[gameVersions allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        if ([obj1 isEqualToString:@"全部"]) return NSOrderedAscending;
        if ([obj2 isEqualToString:@"全部"]) return NSOrderedDescending;
        return [obj2 compare:obj1 options:NSNumericSearch];
    }];

    self.availableLoaders = [[loaders allObjects] sortedArrayUsingSelector:@selector(compare:)];

    self.selectedGameVersion = self.availableGameVersions.firstObject;
    self.selectedLoader = self.availableLoaders.firstObject;

    [self updateFilterButtons];
}

- (void)updateFilterButtons {
    // Game Version Button Menu
    NSMutableArray<UIAction *> *gameVersionActions = [NSMutableArray array];
    for (NSString *version in self.availableGameVersions) {
        UIAction *action = [UIAction actionWithTitle:version image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            self.selectedGameVersion = action.title;
            [self filterAndReload];
            [self updateFilterButtons]; // Update state
        }];
        if ([self.selectedGameVersion isEqualToString:version]) {
            action.state = UIMenuElementStateOn;
        }
        [gameVersionActions addObject:action];
    }
    self.gameVersionFilterButton.menu = [UIMenu menuWithTitle:@"选择游戏版本" children:gameVersionActions];
    [self.gameVersionFilterButton setTitle:self.selectedGameVersion forState:UIControlStateNormal];

    // Loader Button Menu
    NSMutableArray<UIAction *> *loaderActions = [NSMutableArray array];
    for (NSString *loader in self.availableLoaders) {
        UIAction *action = [UIAction actionWithTitle:loader image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            self.selectedLoader = action.title;
            [self filterAndReload];
            [self updateFilterButtons]; // Update state
        }];
        if ([self.selectedLoader isEqualToString:loader]) {
            action.state = UIMenuElementStateOn;
        }
        [loaderActions addObject:action];
    }
    self.loaderFilterButton.menu = [UIMenu menuWithTitle:@"选择加载器" children:loaderActions];
    [self.loaderFilterButton setTitle:self.selectedLoader forState:UIControlStateNormal];
}

- (void)filterChanged {
    // This method is now effectively a passthrough to filterAndReload
    [self filterAndReload];
}

- (void)filterAndReload {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(ModVersion *evaluatedObject, NSDictionary *bindings) {
        BOOL gameVersionMatch = [self.selectedGameVersion isEqualToString:@"全部"] || [evaluatedObject.gameVersions containsObject:self.selectedGameVersion];
        BOOL loaderMatch = [self.selectedLoader isEqualToString:@"全部"] || [evaluatedObject.loaders containsObject:self.selectedLoader.lowercaseString];
        return gameVersionMatch && loaderMatch;
    }];

    self.filteredVersions = [self.allVersions filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredVersions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModVersionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModVersionCell" forIndexPath:indexPath];
    ModVersion *version = self.filteredVersions[indexPath.row];
    [cell configureWithVersion:version];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ModVersion *selectedVersion = self.filteredVersions[indexPath.row];
    if ([self.delegate respondsToSelector:@selector(modVersionViewController:didSelectVersion:)]) {
        [self.delegate modVersionViewController:self didSelectVersion:selectedVersion];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
