//
//  ModInfoViewController.m
//  AmethystMods
//
//  Created by iFlow on 2025-09-30.
//

#import "ModInfoViewController.h"
#import <UIKit/UIKit.h>
#import "ModItem.h"
#import "UnzipKit.h"

@interface ModInfoViewController () {
    ModItem *_modItem;
    UIImageView *_iconView;
    UILabel *_nameLabel;
    UILabel *_versionLabel;
    UILabel *_fileNameLabel;
    UILabel *_descriptionLabel;
    UIButton *_websiteButton;
    UIScrollView *_scrollView;
    UIStackView *_stackView;
}

@end

@implementation ModInfoViewController

- (instancetype)initWithModItem:(ModItem *)modItem {
    if (self = [super init]) {
        _modItem = modItem;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Mod信息";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupUI];
    [self loadModInfo];
}

- (void)setupUI {
    // 创建滚动视图
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];
    
    // 创建堆栈视图
    _stackView = [[UIStackView alloc] init];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = 16.0;
    _stackView.alignment = UIStackViewAlignmentLeading;
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_stackView];
    
    // 创建组件
    _iconView = [[UIImageView alloc] init];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.layer.cornerRadius = 8.0;
    _iconView.clipsToBounds = YES;
    _iconView.backgroundColor = [UIColor systemGrayColor];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.font = [UIFont boldSystemFontOfSize:20];
    _nameLabel.numberOfLines = 0;
    
    _versionLabel = [[UILabel alloc] init];
    _versionLabel.font = [UIFont systemFontOfSize:16];
    _versionLabel.textColor = [UIColor systemGrayColor];
    
    _fileNameLabel = [[UILabel alloc] init];
    _fileNameLabel.font = [UIFont systemFontOfSize:14];
    _fileNameLabel.textColor = [UIColor systemGrayColor];
    
    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.font = [UIFont systemFontOfSize:16];
    _descriptionLabel.numberOfLines = 0;
    
    _websiteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_websiteButton setTitle:@"访问网站" forState:UIControlStateNormal];
    [_websiteButton addTarget:self action:@selector(openWebsite) forControlEvents:UIControlEventTouchUpInside];
    _websiteButton.hidden = YES;
    
    // 添加到堆栈视图
    [_stackView addArrangedSubview:_iconView];
    [_stackView addArrangedSubview:_nameLabel];
    [_stackView addArrangedSubview:_versionLabel];
    [_stackView addArrangedSubview:_fileNameLabel];
    [_stackView addArrangedSubview:_descriptionLabel];
    [_stackView addArrangedSubview:_websiteButton];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_stackView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_stackView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-16],
        [_stackView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-32],
        
        [_iconView.widthAnchor constraintEqualToConstant:64],
        [_iconView.heightAnchor constraintEqualToConstant:64]
    ]];
}

- (void)loadModInfo {
    // 设置基本信息
    _nameLabel.text = _modItem.displayName ?: _modItem.fileName;
    _versionLabel.text = _modItem.version ?: @"未知版本";
    _fileNameLabel.text = _modItem.fileName;
    _descriptionLabel.text = _modItem.modDescription ?: @"无描述";
    
    // 设置网站按钮
    if (_modItem.homepage && _modItem.homepage.length > 0) {
        _websiteButton.hidden = NO;
    }
    
    // 加载图标
    if (_modItem.iconURL && _modItem.iconURL.length > 0) {
        NSURL *iconURL = [NSURL URLWithString:_modItem.iconURL];
        if (iconURL) {
            NSData *iconData = [NSData dataWithContentsOfURL:iconURL];
            if (iconData) {
                UIImage *iconImage = [UIImage imageWithData:iconData];
                if (iconImage) {
                    _iconView.image = iconImage;
                }
            }
        }
    }
}

- (void)openWebsite {
    if (_modItem.homepage && _modItem.homepage.length > 0) {
        NSURL *url = [NSURL URLWithString:_modItem.homepage];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

@end