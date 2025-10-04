//
//  ModRollbackViewController.m
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import "ModRollbackViewController.h"
#import "ModBackupManager.h"
#import "ModService.h"

@interface ModRollbackViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) ModItem *modItem;
@property (nonatomic, strong) NSArray<NSString *> *backupFiles;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ModRollbackViewController

- (instancetype)initWithModItem:(ModItem *)modItem {
    if (self = [super init]) {
        _modItem = modItem;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"版本回滚";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self loadBackupFiles];
    [self setupUI];
}

- (void)loadBackupFiles {
    self.backupFiles = [[ModBackupManager sharedManager] getBackupFilesForMod:self.modItem];
}

- (void)setupUI {
    // 创建表格视图
    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
    
    // 注册单元格
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"BackupCell"];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.backupFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BackupCell" forIndexPath:indexPath];
    
    NSString *backupPath = self.backupFiles[indexPath.row];
    NSString *fileName = [backupPath lastPathComponent];
    
    cell.textLabel.text = fileName;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *backupPath = self.backupFiles[indexPath.row];
    
    // 确认回滚操作
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认回滚"
                                                                   message:@"确定要回滚到此版本吗？当前版本将被备份。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self performRollbackWithBackupPath:backupPath];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performRollbackWithBackupPath:(NSString *)backupPath {
    // 备份当前版本
    NSError *backupError;
    if (![[ModBackupManager sharedManager] backupMod:self.modItem error:&backupError]) {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"备份失败"
                                                                           message:backupError.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }
    
    // 执行回滚
    NSError *restoreError;
    if (![[ModBackupManager sharedManager] restoreModFromBackup:backupPath mod:self.modItem error:&restoreError]) {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"回滚失败"
                                                                           message:restoreError.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }
    
    // 刷新备份文件列表
    [self loadBackupFiles];
    [self.tableView reloadData];
    
    // 显示成功消息
    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"回滚成功"
                                                                          message:@"Mod已成功回滚到选定版本。"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [successAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:successAlert animated:YES completion:nil];
}

@end