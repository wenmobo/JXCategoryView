//
//  WBCategoryListContainerView.m
//  Example
//
//  Created by wenbo on 2020/12/30.
//  Copyright © 2020 jiaxin. All rights reserved.
//

#import "WBCategoryListContainerView.h"
#import <objc/runtime.h>
#import "RTLManager.h"

@interface WBCategoryListContainerViewController : UIViewController

@property (copy) void(^viewWillAppearBlock)(void);
@property (copy) void(^viewDidAppearBlock)(void);
@property (copy) void(^viewWillDisappearBlock)(void);
@property (copy) void(^viewDidDisappearBlock)(void);
@end

@implementation WBCategoryListContainerViewController
- (void)dealloc
{
    self.viewWillAppearBlock = nil;
    self.viewDidAppearBlock = nil;
    self.viewWillDisappearBlock = nil;
    self.viewDidDisappearBlock = nil;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.viewWillAppearBlock();
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.viewDidAppearBlock();
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.viewWillDisappearBlock();
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.viewDidDisappearBlock();
}
- (BOOL)shouldAutomaticallyForwardAppearanceMethods { return NO; }
@end


@interface WBCategoryListContainerView () <UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) id<WBCategoryListContainerViewDelegate> delegate;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, id<WBCategoryListContentViewDelegate>> *validListDict;
@property (nonatomic, assign) NSInteger willAppearIndex;
@property (nonatomic, assign) NSInteger willDisappearIndex;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) WBCategoryListContainerViewController *containerVC;

@property (nonatomic, assign) CGPoint lastContentViewContentOffset;
@property (nonatomic, strong) NSMutableArray <id<WBCategoryListContentViewDelegate>>*cachedArray;

@end

@implementation WBCategoryListContainerView

- (void)dealloc {
    if (self.scrollView) {
        [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    }
}

- (instancetype)initWithType:(WBCategoryListContainerType)type delegate:(id<WBCategoryListContainerViewDelegate>)delegate{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _containerType = type;
        _delegate = delegate;
        _validListDict = [NSMutableDictionary dictionary];
        _willAppearIndex = -1;
        _willDisappearIndex = -1;
        _initListPercent = 0.01;
        _cacheCount = -1;
        [self initializeViews];
    }
    return self;
}

- (void)initializeViews {
    _listCellBackgroundColor = [UIColor whiteColor];
    _containerVC = [[WBCategoryListContainerViewController alloc] init];
    self.containerVC.view.backgroundColor = [UIColor clearColor];
    [self addSubview:self.containerVC.view];
    __weak typeof(self) weakSelf = self;
    self.containerVC.viewWillAppearBlock = ^{
        [weakSelf listWillAppear:weakSelf.currentIndex];
    };
    self.containerVC.viewDidAppearBlock = ^{
        [weakSelf listDidAppear:weakSelf.currentIndex];
    };
    self.containerVC.viewWillDisappearBlock = ^{
        [weakSelf listWillDisappear:weakSelf.currentIndex];
    };
    self.containerVC.viewDidDisappearBlock = ^{
        [weakSelf listDidDisappear:weakSelf.currentIndex];
    };
    if (self.containerType == WBCategoryListContainerType_ScrollView) {
        if (self.delegate &&
            [self.delegate respondsToSelector:@selector(scrollViewClassInlistContainerView:)] &&
            [[self.delegate scrollViewClassInlistContainerView:self] isKindOfClass:object_getClass([UIScrollView class])]) {
            _scrollView = (UIScrollView *)[[[self.delegate scrollViewClassInlistContainerView:self] alloc] init];
        }else {
            _scrollView = [[UIScrollView alloc] init];
        }
        self.scrollView.delegate = self;
        self.scrollView.pagingEnabled = YES;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        self.scrollView.scrollsToTop = NO;
        self.scrollView.bounces = NO;
        if (@available(iOS 11.0, *)) {
            if ([self.scrollView respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
                self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
            }
        }
        [RTLManager horizontalFlipViewIfNeeded:self.scrollView];
        [self.containerVC.view addSubview:self.scrollView];
    }else {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.minimumLineSpacing = 0;
        layout.minimumInteritemSpacing = 0;
        if (self.delegate &&
            [self.delegate respondsToSelector:@selector(scrollViewClassInlistContainerView:)] &&
            [[self.delegate scrollViewClassInlistContainerView:self] isKindOfClass:object_getClass([UICollectionView class])]) {
            _collectionView = (UICollectionView *)[[[self.delegate scrollViewClassInlistContainerView:self] alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        }else {
            _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        }
        self.collectionView.pagingEnabled = YES;
        self.collectionView.showsHorizontalScrollIndicator = NO;
        self.collectionView.showsVerticalScrollIndicator = NO;
        self.collectionView.scrollsToTop = NO;
        self.collectionView.bounces = NO;
        self.collectionView.dataSource = self;
        self.collectionView.delegate = self;
        [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
        if (@available(iOS 10.0, *)) {
            self.collectionView.prefetchingEnabled = NO;
        }
        if (@available(iOS 11.0, *)) {
            if ([self.collectionView respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
                self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
            }
        }
        if ([RTLManager supportRTL]) {
            self.collectionView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
            [RTLManager horizontalFlipView:self.collectionView];
        }
        [self.containerVC.view addSubview:self.collectionView];
        //让外部统一访问scrollView
        _scrollView = _collectionView;
    }
    
    /// kvo
    [_scrollView addObserver:self
                  forKeyPath:@"contentOffset"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];

    UIResponder *next = newSuperview;
    while (next != nil) {
        if ([next isKindOfClass:[UIViewController class]]) {
            [((UIViewController *)next) addChildViewController:self.containerVC];
            break;
        }
        next = next.nextResponder;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.containerVC.view.frame = self.bounds;
    if (self.containerType == WBCategoryListContainerType_ScrollView) {
        if (CGRectEqualToRect(self.scrollView.frame, CGRectZero) ||  !CGSizeEqualToSize(self.scrollView.bounds.size, self.bounds.size)) {
            self.scrollView.frame = self.bounds;
            self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width*[self.delegate numberOfListsInlistContainerView:self], self.scrollView.bounds.size.height);
            [_validListDict enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull index, id<WBCategoryListContentViewDelegate>  _Nonnull list, BOOL * _Nonnull stop) {
                [list listView].frame = CGRectMake(index.intValue*self.scrollView.bounds.size.width, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
            }];
            self.scrollView.contentOffset = CGPointMake(self.currentIndex*self.scrollView.bounds.size.width, 0);
        }else {
            self.scrollView.frame = self.bounds;
            self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width*[self.delegate numberOfListsInlistContainerView:self], self.scrollView.bounds.size.height);
        }
    }else {
        if (CGRectEqualToRect(self.collectionView.frame, CGRectZero) ||  !CGSizeEqualToSize(self.collectionView.bounds.size, self.bounds.size)) {
            [self.collectionView.collectionViewLayout invalidateLayout];
            self.collectionView.frame = self.bounds;
            [self.collectionView reloadData];
            [self.collectionView setContentOffset:CGPointMake(self.collectionView.bounds.size.width*self.currentIndex, 0) animated:NO];
        }else {
            self.collectionView.frame = self.bounds;
        }
    }
}


- (void)setinitListPercent:(CGFloat)initListPercent {
    _initListPercent = initListPercent;
    if (initListPercent <= 0 || initListPercent >= 1) {
        NSAssert(NO, @"initListPercent值范围为开区间(0,1)，即不包括0和1");
    }
}

- (void)setBounces:(BOOL)bounces {
    _bounces = bounces;
    self.scrollView.bounces = bounces;
}

#pragma mark - UICollectionViewDelegate, UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.delegate numberOfListsInlistContainerView:self];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.contentView.backgroundColor = self.listCellBackgroundColor;
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(indexPath.item)];
    if (list != nil) {
        //fixme:如果list是UIViewController，如果这里的frame修改是`[list listView].frame = cell.bounds;`。那么就必须给list vc添加如下代码:
        //- (void)loadView {
        //    self.view = [[UIView alloc] init];
        //}
        //所以，总感觉是把UIViewController当做普通view使用，导致了系统内部的bug。所以，缓兵之计就是用下面的方法，暂时解决问题。
        if ([list isKindOfClass:[UIViewController class]]) {
            [list listView].frame = cell.contentView.bounds;
        } else {
            [list listView].frame = cell.bounds;
        }
        [cell.contentView addSubview:[list listView]];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return self.bounds.size;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerViewDidScroll:)]) {
        [self.delegate listContainerViewDidScroll:scrollView];
    }

    if (!scrollView.isDragging && !scrollView.isTracking && !scrollView.isDecelerating) {
        return;
    }
    CGFloat ratio = scrollView.contentOffset.x/scrollView.bounds.size.width;
    NSInteger maxCount = round(scrollView.contentSize.width/scrollView.bounds.size.width);
    NSInteger leftIndex = floorf(ratio);
    leftIndex = MAX(0, MIN(maxCount - 1, leftIndex));
    NSInteger rightIndex = leftIndex + 1;
    if (ratio < 0 || rightIndex >= maxCount) {
        [self listDidAppearOrDisappear:scrollView];
        return;
    }
    CGFloat remainderRatio = ratio - leftIndex;
    if (rightIndex == self.currentIndex) {
        //当前选中的在右边，用户正在从右边往左边滑动
        if (self.validListDict[@(leftIndex)] == nil && remainderRatio < (1 - self.initListPercent)) {
            [self initListIfNeededAtIndex:leftIndex];
        }else if (self.validListDict[@(leftIndex)] != nil) {
            if (self.willAppearIndex == -1) {
                self.willAppearIndex = leftIndex;
                [self listWillAppear:self.willAppearIndex];
            }
        }
        if (self.willDisappearIndex == -1) {
            self.willDisappearIndex = rightIndex;
            [self listWillDisappear:self.willDisappearIndex];
        }
    }else {
        //当前选中的在左边，用户正在从左边往右边滑动
        if (self.validListDict[@(rightIndex)] == nil && remainderRatio > self.initListPercent) {
            [self initListIfNeededAtIndex:rightIndex];
        }else if (self.validListDict[@(rightIndex)] != nil) {
            if (self.willAppearIndex == -1) {
                self.willAppearIndex = rightIndex;
                [self listWillAppear:self.willAppearIndex];
            }
        }
        if (self.willDisappearIndex == -1) {
            self.willDisappearIndex = leftIndex;
            [self listWillDisappear:self.willDisappearIndex];
        }
    }
    [self listDidAppearOrDisappear:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerViewDidEndDecelerating:)]) {
        [self.delegate listContainerViewDidEndDecelerating:scrollView];
    }
    //滑动到一半又取消滑动处理
    if (self.willDisappearIndex != -1) {
        [self listWillAppear:self.willDisappearIndex];
        [self listWillDisappear:self.willAppearIndex];
        [self listDidAppear:self.willDisappearIndex];
        [self listDidDisappear:self.willAppearIndex];
        self.willDisappearIndex = -1;
        self.willAppearIndex = -1;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerViewWillBeginDragging:)]) {
        [self.delegate listContainerViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerViewDidEndDragging:willDecelerate:)]) {
        [self.delegate listContainerViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

// MARK: - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        CGPoint contentOffset = [change[NSKeyValueChangeNewKey] CGPointValue];
        if (self.scrollView.isTracking || self.scrollView.isDecelerating) {
            [self contentOffsetOfContentScrollViewDidChanged:contentOffset];
        }
        self.lastContentViewContentOffset = contentOffset;
    }
}

- (void)contentOffsetOfContentScrollViewDidChanged:(CGPoint)contentOffset {
    CGFloat ratio = contentOffset.x / self.scrollView.bounds.size.width;
    NSInteger dataSourceCount = [self.delegate numberOfListsInlistContainerView:self];
    if (ratio > dataSourceCount - 1 || ratio < 0) {
        /// 超过了边界，不需要处理
        return;
    }
    
    if (contentOffset.x == 0 && self.currentIndex == 0 && self.lastContentViewContentOffset.x == 0) {
        /// 滚动到了最左边，且已经选中了第一个，且之前的contentOffset.x为0
        return;
    }
    
    CGFloat maxContentOffsetX = self.scrollView.contentSize.width - self.scrollView.bounds.size.width;
    if (contentOffset.x == maxContentOffsetX && self.currentIndex == dataSourceCount - 1 && self.lastContentViewContentOffset.x == maxContentOffsetX) {
        /// 滚动到了最右边，且已经选中了最后一个，且之前的contentOffset.x为maxContentOffsetX
        return;
    }
    
    ratio = MAX(0, MIN(dataSourceCount - 1, ratio));
    NSInteger baseIndex = floorf(ratio);
    CGFloat remainderRatio = ratio - baseIndex;
    if (remainderRatio == 0) {
        /// 快速滑动翻页，用户一直在拖拽contentScrollView，需要更新选中状态
        /// 滑动一小段距离，然后放开回到原位，contentOffset同样的值会回调多次。例如在index为1的情况，滑动放开回到原位，contentOffset会多次回调CGPoint(width, 0)
        if (!(self.lastContentViewContentOffset.x == contentOffset.x && self.currentIndex == baseIndex)) {
            [self scrollSelectItemAtIndex:baseIndex];
        }
    } else {
        /// 快速滑动翻页，当remainderRatio没有变成0，但是已经翻页了，需要通过下面的判断，触发选中
        if (fabs(ratio - self.currentIndex) > 1) {
            NSInteger targetIndex = baseIndex;
            if (ratio < self.currentIndex) {
                targetIndex = baseIndex + 1;
            }
            [self scrollSelectItemAtIndex:targetIndex];
        }
    }
}

- (void)scrollSelectItemAtIndex:(NSInteger)index {
    NSInteger dataSourceCount = [self.delegate numberOfListsInlistContainerView:self];
    if (index < 0 || index >= dataSourceCount) {
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerView:didScrollSelectedItemAtIndex:)]) {
        [self.delegate listContainerView:self didScrollSelectedItemAtIndex:index];
    }
}

#pragma mark - WBCategoryViewListContainer

- (UIScrollView *)contentScrollView {
    return self.scrollView;
}

- (void)setDefaultSelectedIndex:(NSInteger)index {
    self.currentIndex = index;
}

- (void)didClickSelectedItemAtIndex:(NSInteger)index {
    if (![self checkIndexValid:index]) {
        return;
    }
    self.willAppearIndex = -1;
    self.willDisappearIndex = -1;
    if (self.currentIndex != index) {
        [self listWillDisappear:self.currentIndex];
        [self listDidDisappear:self.currentIndex];
        [self listWillAppear:index];
        [self listDidAppear:index];
    }
}

- (void)reloadData {
    for (id<WBCategoryListContentViewDelegate> list in _validListDict.allValues) {
        [[list listView] removeFromSuperview];
        if ([list isKindOfClass:[UIViewController class]]) {
            [(UIViewController *)list removeFromParentViewController];
        }
    }
    [_validListDict removeAllObjects];

    if (self.containerType == WBCategoryListContainerType_ScrollView) {
        self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width*[self.delegate numberOfListsInlistContainerView:self], self.scrollView.bounds.size.height);
    }else {
        [self.collectionView reloadData];
    }
    [self listWillAppear:self.currentIndex];
    [self listDidAppear:self.currentIndex];
}

#pragma mark - Private

- (void)initListIfNeededAtIndex:(NSInteger)index {
    if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerView:canInitListAtIndex:)]) {
        BOOL canInitList = [self.delegate listContainerView:self canInitListAtIndex:index];
        if (!canInitList) {
            return;
        }
    }
    
    /// 缓存数量大于置顶值，移除最早创建的视图
    if (self.cacheCount > 0 && self.cachedArray.count >= self.cacheCount) {
        id<WBCategoryListContentViewDelegate> earliestList = self.cachedArray.firstObject;
        
        [_validListDict enumerateKeysAndObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSNumber * _Nonnull key, id<WBCategoryListContentViewDelegate>  _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj == earliestList) {
                [[obj listView] removeFromSuperview];
                if ([obj isKindOfClass:[UIViewController class]]) {
                    [(UIViewController *)obj removeFromParentViewController];
                }
                [_validListDict removeObjectForKey:key];
                [self.cachedArray removeObject:earliestList];
                *stop = YES;
            }
        }];
    }
    
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
    if (list != nil) {
        //列表已经创建好了
        return;
    }
    list = [self.delegate listContainerView:self initListForIndex:index];
    
    /// 添加到缓存数组
    [self.cachedArray addObject:list];
    
    if ([list isKindOfClass:[UIViewController class]]) {
        [self.containerVC addChildViewController:(UIViewController *)list];
    }
    _validListDict[@(index)] = list;

    if (self.containerType == WBCategoryListContainerType_ScrollView) {
        [list listView].frame = CGRectMake(index*self.scrollView.bounds.size.width, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
        [self.scrollView addSubview:[list listView]];
        [RTLManager horizontalFlipViewIfNeeded:[list listView]];
    }else {
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
        for (UIView *subview in cell.contentView.subviews) {
            [subview removeFromSuperview];
        }
        [list listView].frame = cell.contentView.bounds;
        [cell.contentView addSubview:[list listView]];
    }
}

- (void)listWillAppear:(NSInteger)index {
    if (![self checkIndexValid:index]) {
        return;
    }
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
    if (list != nil) {
        if (list && [list respondsToSelector:@selector(listWillAppear)]) {
            [list listWillAppear];
        }
        if ([list isKindOfClass:[UIViewController class]]) {
            UIViewController *listVC = (UIViewController *)list;
            [listVC beginAppearanceTransition:YES animated:NO];
        }
    }else {
        //当前列表未被创建（页面初始化或通过点击触发的listWillAppear）
        BOOL canInitList = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(listContainerView:canInitListAtIndex:)]) {
            canInitList = [self.delegate listContainerView:self canInitListAtIndex:index];
        }
        if (canInitList) {
            id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
            if (list == nil) {
                list = [self.delegate listContainerView:self initListForIndex:index];
                if ([list isKindOfClass:[UIViewController class]]) {
                    [self.containerVC addChildViewController:(UIViewController *)list];
                }
                _validListDict[@(index)] = list;
            }
            if (self.containerType == WBCategoryListContainerType_ScrollView) {
                if ([list listView].superview == nil) {
                    [list listView].frame = CGRectMake(index*self.scrollView.bounds.size.width, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
                    [self.scrollView addSubview:[list listView]];
                    [RTLManager horizontalFlipViewIfNeeded:[list listView]];

                    if (list && [list respondsToSelector:@selector(listWillAppear)]) {
                        [list listWillAppear];
                    }
                    if ([list isKindOfClass:[UIViewController class]]) {
                        UIViewController *listVC = (UIViewController *)list;
                        [listVC beginAppearanceTransition:YES animated:NO];
                    }
                }
            }else {
                UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                for (UIView *subview in cell.contentView.subviews) {
                    [subview removeFromSuperview];
                }
                [list listView].frame = cell.contentView.bounds;
                [cell.contentView addSubview:[list listView]];

                if (list && [list respondsToSelector:@selector(listWillAppear)]) {
                    [list listWillAppear];
                }
                if ([list isKindOfClass:[UIViewController class]]) {
                    UIViewController *listVC = (UIViewController *)list;
                    [listVC beginAppearanceTransition:YES animated:NO];
                }
            }
        }
    }
}

- (void)listDidAppear:(NSInteger)index {
    if (![self checkIndexValid:index]) {
        return;
    }
    self.currentIndex = index;
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
    if (list && [list respondsToSelector:@selector(listDidAppear)]) {
        [list listDidAppear];
    }
    if ([list isKindOfClass:[UIViewController class]]) {
        UIViewController *listVC = (UIViewController *)list;
        [listVC endAppearanceTransition];
    }
}

- (void)listWillDisappear:(NSInteger)index {
    if (![self checkIndexValid:index]) {
        return;
    }
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
    if (list && [list respondsToSelector:@selector(listWillDisappear)]) {
        [list listWillDisappear];
    }
    if ([list isKindOfClass:[UIViewController class]]) {
        UIViewController *listVC = (UIViewController *)list;
        [listVC beginAppearanceTransition:NO animated:NO];
    }
}

- (void)listDidDisappear:(NSInteger)index {
    if (![self checkIndexValid:index]) {
        return;
    }
    id<WBCategoryListContentViewDelegate> list = _validListDict[@(index)];
    if (list && [list respondsToSelector:@selector(listDidDisappear)]) {
        [list listDidDisappear];
    }
    if ([list isKindOfClass:[UIViewController class]]) {
        UIViewController *listVC = (UIViewController *)list;
        [listVC endAppearanceTransition];
    }
}

- (BOOL)checkIndexValid:(NSInteger)index {
    NSUInteger count = [self.delegate numberOfListsInlistContainerView:self];
    if (count <= 0 || index >= count) {
        return NO;
    }
    return YES;
}

- (void)listDidAppearOrDisappear:(UIScrollView *)scrollView {
    CGFloat currentIndexPercent = scrollView.contentOffset.x/scrollView.bounds.size.width;
    if (self.willAppearIndex != -1 || self.willDisappearIndex != -1) {
        NSInteger disappearIndex = self.willDisappearIndex;
        NSInteger appearIndex = self.willAppearIndex;
        if (self.willAppearIndex > self.willDisappearIndex) {
            //将要出现的列表在右边
            if (currentIndexPercent >= self.willAppearIndex) {
                self.willDisappearIndex = -1;
                self.willAppearIndex = -1;
                [self listDidDisappear:disappearIndex];
                [self listDidAppear:appearIndex];
            }
        }else {
            //将要出现的列表在左边
            if (currentIndexPercent <= self.willAppearIndex) {
                self.willDisappearIndex = -1;
                self.willAppearIndex = -1;
                [self listDidDisappear:disappearIndex];
                [self listDidAppear:appearIndex];
            }
        }
    }
}

// MARK: - getter
- (NSMutableArray<id<WBCategoryListContentViewDelegate>> *)cachedArray {
    if (!_cachedArray) {
        _cachedArray = @[].mutableCopy;
    }
    return _cachedArray;
}

@end
