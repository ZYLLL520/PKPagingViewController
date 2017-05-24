//
//  PKPageViewController.m
//  Pook
//
//  Created by 郑玉林 on 16/6/22.
//  Copyright © 2016年 haidai. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//


#import "PKPagingViewController.h"

#define kDefaultVCIndex (-1)
#define kDistance (kScreenWidth * 0.5 - 44)

#ifdef DEBUG
#define PKLog(fmt, ...) NSLog((@"[%d] " fmt), __LINE__, ##__VA_ARGS__);
#else
#define PKLog(...);
#endif

#define kScreenBounds ([UIScreen mainScreen].bounds)
#define kScreenWidth (kScreenBounds.size.width)
#define kScreenHeight (kScreenBounds.size.height)
#define kNavBarHeight (64)
#define kSigleNavBarHeight (44)
#define kStatusBarHeight (20)
#define kTabBarHeight (44)

//====================== 通知类 ===================

NSString * const PKPageVCDidClickItemNoti = @"PKPageVCDidClickItemNotification";


//====================== 视图类 ===================

static NSString * const UIIViewWillAppearSEL    = @"viewWillAppear:";

static NSString * const UIIViewDidAppearSEL     = @"viewDidAppear:";

static NSString * const UIIViewWillDisappearSEL = @"viewWillDisappear:";

static NSString * const UIIViewDidDisappearSEL  = @"viewDidDisappear:";


//====================== 状态类 ===================

/// 视图的显示状态
typedef NS_ENUM(NSInteger, PKViewStatus) {
    PKViewStatus_Default,           /**< 默认状态 */
    PKViewStatus_Willappear,        /**< 将要显示 */
    PKViewStatus_WillDisappear      /**< 将要消失 */
};

/// 视图状态的结构体
struct PKVCStatus {
    NSInteger       index;  /**< 视图的位置索引 */
    PKViewStatus    status; /**< 视图的显示状态 */
};


@interface PKPagingViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate>

/**
 *  导航栏标题的默认状态颜色
 */
@property (nonatomic, strong) UIColor *itemNormalColor;

/**
 *  导航栏标题的高亮状态颜色
 */
@property (nonatomic, strong) UIColor *itemHighlightedColor;

/**
 *  顶部的导航栏
 */
@property (nonatomic,  strong) UIView *navigationBarView;

/**
 *  滚动视图
 */
@property (nonatomic,   weak) UIScrollView *scrollView;

/**
 *  导航栏上的 item 集合
 */
@property (nonatomic, strong) NSArray<UILabel *> *navItemsViews;

/**
 *  子控制器的集合 (key -> index, value -> view)
 */
@property (nonatomic, strong) NSDictionary *viewControllers;

/**
 *  当前显示的页面索引
 */
@property (nonatomic, assign, readwrite) NSInteger indexSelected;

// TODO: 导航和滚动只能存在一个处理动作
@property (nonatomic, assign, getter=isUserInteraction) BOOL userInteraction;

//========= 判断滚动的情况 =============

/**
 *  初始的偏移量
 */
@property (nonatomic, assign) CGPoint lastPoint;

/**
 *  将要显示控制器的集合
 */
@property (nonatomic, assign)  struct PKVCStatus willAppearVC;

/**
 *  是否处于拖拽状态
 */
@property (nonatomic, assign, getter=isDragging) BOOL dragging;

@end

@implementation PKPagingViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _viewControllers = nil;
    _navItemsViews = nil;
}

#pragma mark - Public Methods


- (void)setCurrentIndex:(NSInteger)index animated:(BOOL)animated {
    
    if(index < 0 || index > self.navigationBarView.subviews.count - 1){
        PKLog(@"The index is out of range of subviews's count!");
        return;
    }
    
    self.indexSelected = index;
    CGFloat xOffset    = (index * ((int)kScreenWidth));
    [self.scrollView setContentOffset:CGPointMake(xOffset, self.scrollView.contentOffset.y) animated:animated];
}

- (void)updateUserInteractionOnNavigation:(BOOL)activate{
    self.userInteraction = activate;
}

+ (NSInteger)indexOfMainPage {
    return 1;
}

#pragma mark - Initailzion

- (instancetype)initWithNavBarItems:(NSArray<UILabel *> *)items
              navBarBackgroundColor:(UIColor *)bgColor
                        controllers:(NSArray<UIViewController *> *)controllers {
    
    return [self initWithNavBarItems:items
                         normalColor:nil
                    highlightedColor:nil
               navBarBackgroundColor:bgColor
                         controllers:controllers];
}

- (instancetype)initWithNavBarItems:(NSArray<UILabel *> *)items
                   normalColor:(UIColor *)normalColor
                   highlightedColor:(UIColor *)highlightedColor
              navBarBackgroundColor:(UIColor *)bgColor
                        controllers:(NSArray<UIViewController *> *)controllers {

    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // 初始化默认值
        _userInteraction = YES;
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.navigationController.interactivePopGestureRecognizer.delegate = self;
        _itemNormalColor = normalColor;
        _itemHighlightedColor = highlightedColor;
        // 创建导航栏
        [self createNavigationBarViewWithColor:bgColor items:items];
        //  ViewControllers
        NSMutableArray *viewArr = [NSMutableArray arrayWithCapacity:controllers.count];
        NSMutableArray *indexArr = [NSMutableArray arrayWithCapacity:controllers.count];
        
        for (int i = 0; i < controllers.count; i++) {
            UIViewController *vc = controllers[i];
            vc.automaticallyAdjustsScrollViewInsets = NO;
            [self addChildViewController:vc];
            [viewArr addObject:vc.view];
            [indexArr addObject:@(i)];
        }
        _viewControllers = [[NSDictionary alloc] initWithObjects:viewArr forKeys:indexArr];
        // Notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark - View LifeCycle


- (void)loadView {
    [super loadView];
    
    [self addControllerViews];
    [self.view insertSubview:self.navigationBarView atIndex:1];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationController.navigationBar setHidden:YES];
    [self setCurrentIndex:[[self class] indexOfMainPage] animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self notifyControllers:_cmd
                     object:@(animated)
                 checkIndex:YES];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self notifyControllers:_cmd
                     object:@(animated)
                 checkIndex:YES];
}


- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self notifyControllers:_cmd
                     object:@(animated)
                 checkIndex:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self notifyControllers:_cmd
                     object:@(animated)
                 checkIndex:YES];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.navigationBarView.frame = CGRectMake(0, 0, kScreenWidth, kNavBarHeight);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - Actions


- (void)tapOnHeader:(UITapGestureRecognizer *)recognizer {
    
    // 点击了指定标题
    if (self.isUserInteraction) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PKPageVCDidClickItemNoti object:@(recognizer.view.tag)];
        UIView *view = [self.viewControllers objectForKey:@(recognizer.view.tag)];
        [self.scrollView scrollRectToVisible:view.frame
                                    animated:YES];
    }
}


#pragma mark - Notification


- (void)orientationChanged:(NSNotification *)notification {
    
    if (!self.isViewLoaded) {
        return;
    }
    
    [self updateNavItems:self.scrollView.contentOffset.x];
    [self setCurrentIndex:self.indexSelected
                 animated:NO];
    [self.scrollView setNeedsUpdateConstraints];
    [self.view setNeedsUpdateConstraints];
}

#pragma mark - ScrollView delegate


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    [self notifyControllers:NSSelectorFromString(UIIViewWillDisappearSEL)
                     object:@(YES)
                 checkIndex:YES
     ];
    
    self.lastPoint = scrollView.contentOffset;
    struct PKVCStatus vc = {kDefaultVCIndex, PKViewStatus_Default};
    self.willAppearVC = vc;
    self.dragging = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView { // 更新导航栏和通知控制器处理事件
    
    if (!self.isViewLoaded) {
        return;
    }
    
    // Update nav items
    [self updateNavItems:scrollView.contentOffset.x];
    
    if(self.pagingViewMoving) {
        self.pagingViewMoving(self.navItemsViews);
    }
    
    if(self.pagingViewMovingRedefine) {
        self.pagingViewMovingRedefine(scrollView, self.navItemsViews);
    }
    
    if (!self.isDragging) {
        return;
    }
    
    CGFloat X = scrollView.contentOffset.x;
    
    NSInteger willIndex = X - self.indexSelected * kScreenWidth;
    if (willIndex > 0) {
        willIndex = self.indexSelected + 1;
    } else if (willIndex < 0) {
        willIndex = self.indexSelected - 1;
    } else {
        willIndex = self.indexSelected;
    }
    
    // 查找即将显示的控制器时
    if (willIndex == self.indexSelected) {
        if (self.willAppearVC.index != self.indexSelected && self.willAppearVC.index != kDefaultVCIndex) {
            [self notifyControllers:NSSelectorFromString(UIIViewDidDisappearSEL) object:@YES index:self.willAppearVC.index];
            struct PKVCStatus vc = {willIndex, PKViewStatus_Default};
            self.willAppearVC = vc;
        }
    } else {
        if (self.willAppearVC.index == kDefaultVCIndex) {
            [self notifyControllers:NSSelectorFromString(UIIViewWillAppearSEL) object:@YES index:willIndex];
            struct PKVCStatus vc = {willIndex, PKViewStatus_Willappear};
            self.willAppearVC = vc;
        } else {
            switch (self.willAppearVC.status) {
                case PKViewStatus_Willappear: {
                    if ((X - self.lastPoint.x) * (willIndex - self.indexSelected) < 0) { // 趋势相反
                        [self notifyControllers:NSSelectorFromString(UIIViewWillDisappearSEL) object:@YES index:willIndex];
                        struct PKVCStatus vc = {willIndex, PKViewStatus_WillDisappear};
                        self.willAppearVC = vc;
                    }
                }
                    break;
                case PKViewStatus_WillDisappear: {
                    if ((X - self.lastPoint.x) * (willIndex - self.indexSelected) > 0) { // 趋势相反
                        [self notifyControllers:NSSelectorFromString(UIIViewWillAppearSEL) object:@YES index:willIndex];
                        struct PKVCStatus vc = {willIndex, PKViewStatus_Willappear};
                        self.willAppearVC = vc;
                    }
                }
                    break;
                case PKViewStatus_Default:
                    break;
            }
        }
    }
    
    self.lastPoint = scrollView.contentOffset;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    self.dragging = NO;
    // 如果结束点和当前索引一致则发送将要消失的事件
    CGFloat endX = targetContentOffset->x;
    
    if (endX - self.indexSelected * kScreenWidth != 0) {
        return;
    }
    // 视图还将回归原位，发送视图即将隐藏的事件
    CGFloat X = scrollView.contentOffset.x;
    
    NSInteger willIndex = X - self.indexSelected * kScreenWidth;
    if (willIndex > 0) {
        willIndex = self.indexSelected + 1;
    } else if (willIndex < 0) {
        willIndex = self.indexSelected - 1;
    } else {
        willIndex = self.indexSelected;
    }
    
    // 如果是即将显示的控制器则发送即将消失的事件
    if (willIndex == self.willAppearVC.index && self.willAppearVC.status == PKViewStatus_Willappear) {
        [self notifyControllers:NSSelectorFromString(UIIViewWillDisappearSEL) object:@YES index:willIndex];
        struct PKVCStatus vc = {willIndex, PKViewStatus_WillDisappear};
        self.willAppearVC = vc;
    }
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    [self sendNewIndex:scrollView];
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    
    [self sendNewIndex:scrollView];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    CGFloat offsetX = self.scrollView.contentOffset.x;
    // 满足条件拦截手势
    if (offsetX > 0) {
        CGFloat scale = offsetX / (CGFloat)kScreenWidth;
        if (floorf(scale) == ceilf(scale)) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Custom Method

- (void)createNavigationBarViewWithColor:(UIColor *)bgColor items:(NSArray<UILabel *> *)items {
    
    UIView *navigationBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kNavBarHeight)];
    navigationBarView.backgroundColor = bgColor;
    self.navigationBarView = navigationBarView;
    // line
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, kNavBarHeight - 1, kScreenWidth, 1)];
    line.backgroundColor = [UIColor lightGrayColor];
    [navigationBarView addSubview:line];
    // Items
    NSMutableArray *navItemsViews = [NSMutableArray arrayWithCapacity:items.count];
    for (int i = 0; i < items.count; i++) {
        UILabel *lab = items[i];
        lab.exclusiveTouch = YES;
        lab.userInteractionEnabled = YES;
        CGSize size = [self getLabelSize:lab];
        CGRect frame = CGRectMake(lab.frame.origin.x, lab.frame.origin.y, size.width, size.height);
        lab.frame = frame;
        lab.tag = i;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(tapOnHeader:)];
        [lab addGestureRecognizer:tap];
        [self.navigationBarView addSubview:lab];
        [navItemsViews addObject:lab];
    }
    self.navItemsViews = navItemsViews;
}

- (void)sendNewIndex:(UIScrollView *)scrollView{
    
    CGFloat xOffset = scrollView.contentOffset.x;
    NSInteger newIndex = ((int) roundf(xOffset) % (self.navigationBarView.subviews.count * (int)kScreenWidth)) / kScreenWidth;
    if(self.indexSelected != newIndex) {
        
        [self notifyControllers:NSSelectorFromString(UIIViewDidDisappearSEL)
                         object:@(YES)
                     checkIndex:YES];
        self.indexSelected = newIndex;
    }  else if (self.willAppearVC.index != kDefaultVCIndex &&
                self.willAppearVC.index != newIndex &&
                self.willAppearVC.status == PKViewStatus_WillDisappear) {
        
        [self notifyControllers:NSSelectorFromString(UIIViewDidDisappearSEL)
                         object:@YES
                          index:self.willAppearVC.index];
    }
    
    if(self.didChangedPage) {
        self.didChangedPage(self.indexSelected);
    }
    
    [self notifyControllers:NSSelectorFromString(UIIViewDidAppearSEL)
                     object:@(YES)
                 checkIndex:YES];
}

/// 获取标签的大小
- (CGSize)getLabelSize:(UILabel *)lab {
    
    CGSize size = [[lab text] sizeWithAttributes:@{NSFontAttributeName:[lab font]}];
    return CGSizeMake(ceil(size.width), ceil(size.height));
}

/// 根据偏移量更新标题栏位置
- (void)updateNavItems:(CGFloat)xOffset {
    
    CGFloat offset = xOffset / (kScreenWidth / kDistance);
    
    [self.navItemsViews enumerateObjectsUsingBlock:^(UILabel * _Nonnull lab, NSUInteger index, BOOL * _Nonnull stop) {

        CGSize size = lab.frame.size;
        CGFloat X = ((kScreenWidth * 0.5 - size.width * 0.5) + index * kDistance) - offset;
        CGFloat Y = (kSigleNavBarHeight - size.height) * 0.5 + kStatusBarHeight;
        lab.frame = CGRectMake(X, Y, size.width, size.height);
        if (self.itemNormalColor && self.itemHighlightedColor) {
            lab.textColor = [self textColorWithOriginX:X];
        }
    }];
}

/// 根据指定位置返回标题栏颜色
- (UIColor *)textColorWithOriginX:(CGFloat)X {
    
    UIColor *color = nil;
    CGFloat minX = 44.0;
    CGFloat mid  = kScreenWidth * 0.5 - minX;
    CGFloat midM = kScreenWidth - minX;
    if (X > minX && X < mid) {
        color = [self gradient:X top:minX + 1 bottom:mid - 1 init:self.itemHighlightedColor goal:self.itemNormalColor];
    } else if (X > mid && X < midM) {
        color = [self gradient:X top:mid + 1 bottom:midM - 1 init:self.itemNormalColor goal:self.itemHighlightedColor];
    } else if (X == mid) {
        color = self.itemHighlightedColor;
    } else {
        color = self.itemNormalColor;
    }
    return color;
}

- (UIColor *)gradient:(double)percent top:(double)topX bottom:(double)bottomX init:(UIColor*)init goal:(UIColor*)goal {
    
    double t = (percent - bottomX) / (topX - bottomX);
    
    t = MAX(0.0, MIN(t, 1.0));
    
    const CGFloat *cgInit = CGColorGetComponents(init.CGColor);
    const CGFloat *cgGoal = CGColorGetComponents(goal.CGColor);
    
    double r = cgInit[0] + t * (cgGoal[0] - cgInit[0]);
    double g = cgInit[1] + t * (cgGoal[1] - cgInit[1]);
    double b = cgInit[2] + t * (cgGoal[2] - cgInit[2]);
    
    return [UIColor colorWithRed:r green:g blue:b alpha:1];
}

/// 添加子视图
- (void)addControllerViews {
    
    CGFloat width = kScreenWidth * self.viewControllers.count;
    CGFloat height = CGRectGetHeight(self.view.bounds) - CGRectGetHeight(self.navigationBarView.bounds);
    self.scrollView.contentSize = (CGSize){width, height};
    // Sort all keys in ascending
    NSArray *sortedIndexes = [self.viewControllers.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *key1, NSNumber *key2) {
        if ([key1 integerValue] > [key2 integerValue]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        if ([key1 integerValue] < [key2 integerValue]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    __block int i = 0;
    [sortedIndexes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIView *v = self.viewControllers[@(idx)];
        v.frame = CGRectMake(kScreenWidth * i, kNavBarHeight, kScreenWidth, kScreenHeight - kNavBarHeight);
        [self.scrollView addSubview:v];
        i++;
    }];
}

- (void)notifyControllers:(SEL)selector object:(id)object checkIndex:(BOOL)index {
    
    if(index && self.childViewControllers.count > self.indexSelected) {
        [self.childViewControllers[self.indexSelected] performSelectorOnMainThread:selector
                                                                        withObject:object
                                                                     waitUntilDone:NO];
    } else {
        [self.childViewControllers enumerateObjectsUsingBlock:^(UIViewController* ctr, NSUInteger idx, BOOL *stop) {
            [ctr performSelectorOnMainThread:selector
                                  withObject:object
                               waitUntilDone:NO];
        }];
    }
}

- (void)notifyControllers:(SEL)selector object:(id)object index:(NSInteger)index {
    if (index < 0 || index >= self.childViewControllers.count) {
        return;
    }
    [self.childViewControllers[index] performSelectorOnMainThread:selector
                                                       withObject:object
                                                    waitUntilDone:NO];
}


#pragma mark - Lazy Load

- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        UIScrollView *scrollView  = [[UIScrollView alloc] initWithFrame:kScreenBounds];
        scrollView.backgroundColor = [UIColor clearColor];
        scrollView.pagingEnabled = YES;
        scrollView.showsVerticalScrollIndicator = NO;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.bounces = NO;
        scrollView.scrollsToTop = NO;
        scrollView.contentInset = UIEdgeInsetsMake(0, 0, -kTabBarHeight, 0);
        scrollView.delegate = self;
        [self.view addSubview:scrollView];
        _scrollView = scrollView;
    }
    return _scrollView;
}

@end
