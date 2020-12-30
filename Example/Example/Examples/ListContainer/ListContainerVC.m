//
//  ListContainerVC.m
//  Example
//
//  Created by wenbo on 2020/12/30.
//  Copyright © 2020 jiaxin. All rights reserved.
//

#import "ListContainerVC.h"
#import "ListVC.h"

#import "WBCategoryListContainerView.h"

@interface ListContainerVC () <WBCategoryListContainerViewDelegate>

@property (nonatomic, strong) WBCategoryListContainerView *listContainerView;

@end

@implementation ListContainerVC

- (void)dealloc {
    NSLog(@"销毁了");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _listContainerView = [[WBCategoryListContainerView alloc] initWithType:WBCategoryListContainerType_CollectionView delegate:self];
    _listContainerView.cacheCount = 2;
    [self.view addSubview:_listContainerView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    _listContainerView.frame = self.view.bounds;
}

// MARK: - WBCategoryListContainerViewDelegate
- (NSInteger)numberOfListsInlistContainerView:(WBCategoryListContainerView *)listContainerView {
    return 20;
}

- (id<WBCategoryListContentViewDelegate>)listContainerView:(WBCategoryListContainerView *)listContainerView initListForIndex:(NSInteger)index {
    ListVC *vc = [[ListVC alloc] init];
    return vc;
}

- (void)listContainerView:(WBCategoryListContainerView *)listContainerView didScrollSelectedItemAtIndex:(NSInteger)index {
    NSLog(@"index = %ld", index);
}

@end
