//
//  PKPageViewController.h
//  Pook<https://github.com/ZYLLL520/PKPagingViewController>
//
//  Created by 郑玉林 on 16/6/22.
//  Copyright © 2016年 Pook. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 点击指定页面的通知名称
extern NSString * const PKPageVCDidClickItemNoti;

typedef void(^PKPagingViewMoving)(NSArray *subviews);
typedef void(^PKPagingViewMovingRedefine)(UIScrollView *scrollView, NSArray *subviews);
typedef void(^PKPagingViewDidChanged)(NSInteger currentPage);

@interface PKPagingViewController : UIViewController

@property (nonatomic, copy) PKPagingViewMovingRedefine pagingViewMovingRedefine;

@property (nonatomic, copy) PKPagingViewMoving pagingViewMoving;

@property (nonatomic, copy) PKPagingViewDidChanged didChangedPage;

/// 当前显示的页面索引
@property (nonatomic, assign, readonly) NSInteger indexSelected;

- (instancetype)initWithNavBarItems:(NSArray<UILabel *> *)items
              navBarBackgroundColor:(UIColor *)bgColor
                        controllers:(NSArray<UIViewController *> *)controllers;

- (instancetype)initWithNavBarItems:(NSArray<UILabel *> *)items
                        normalColor:(nullable UIColor *)normalColor
                   highlightedColor:(nullable UIColor *)highlightedColor
              navBarBackgroundColor:(UIColor *)bgColor
                        controllers:(NSArray<UIViewController *> *)controllers NS_DESIGNATED_INITIALIZER;

/// 跳转到指定页面
- (void)setCurrentIndex:(NSInteger)index animated:(BOOL)animated;

/// 更新导航栏的用户交互状态
- (void)updateUserInteractionOnNavigation:(BOOL)activate;

/// 主页的索引(在判断控件的点击区域和对特殊页面位置做处理时有用)
+ (NSInteger)indexOfMainPage;

//=========================================================

+ (instancetype)new  NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
