#import "ModVersionViewController.h"
#import "installer/modpack/ModrinthAPI.h"
#import "ModVersion.h"
#import "ModVersionTableViewCell.h"

@interface ModVersionViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *gameVersionSegmentedControl;
@property (nonatomic, strong) UISegmentedControl *loaderSegmentedControl;

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
    // Game Version Filter
    self.gameVersionSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"加载中..."]];
    self.gameVersionSegmentedControl.selectedSegmentIndex = 0;
    [self.gameVersionSegmentedControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    self.gameVersionSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.gameVersionSegmentedControl];

    // Loader Filter
    self.loaderSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"加载中..."]];
    self.loaderSegmentedControl.selectedSegmentIndex = 0;
    [self.loaderSegmentedControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    self.loaderSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loaderSegmentedControl];

    [NSLayoutConstraint activateConstraints:@[
        [self.gameVersionSegmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.gameVersionSegmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.gameVersionSegmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],

        [self.loaderSegmentedControl.topAnchor constraintEqualToAnchor:self.gameVersionSegmentedControl.bottomAnchor constant:8],
        [self.loaderSegmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.loaderSegmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[ModVersionTableViewCell class] forCellReuseIdentifier:@"ModVersionCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.loaderSegmentedControl.bottomAnchor constant:8],
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
            [loaders addObject:loader];
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

    [self.gameVersionSegmentedControl removeAllSegments];
    for (NSString *version in self.availableGameVersions) {
        [self.gameVersionSegmentedControl insertSegmentWithTitle:version atIndex:self.gameVersionSegmentedControl.numberOfSegments animated:NO];
    }
    self.gameVersionSegmentedControl.selectedSegmentIndex = 0;

    [self.loaderSegmentedControl removeAllSegments];
    for (NSString *loader in self.availableLoaders) {
        [self.loaderSegmentedControl insertSegmentWithTitle:loader atIndex:self.loaderSegmentedControl.numberOfSegments animated:NO];
    }
    self.loaderSegmentedControl.selectedSegmentIndex = 0;
}

- (void)filterChanged {
    self.selectedGameVersion = [self.gameVersionSegmentedControl titleForSegmentAtIndex:self.gameVersionSegmentedControl.selectedSegmentIndex];
    self.selectedLoader = [self.loaderSegmentedControl titleForSegmentAtIndex:self.loaderSegmentedControl.selectedSegmentIndex];

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
