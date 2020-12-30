//
//  ListVC.m
//  Example
//
//  Created by wenbo on 2020/12/30.
//  Copyright © 2020 jiaxin. All rights reserved.
//

#import "ListVC.h"

#define COLOR_WITH_RGB(R,G,B,A) [UIColor colorWithRed:R green:G blue:B alpha:A]

@interface ListVC ()

@end

@implementation ListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // 设置背景颜色：随机色
    self.view.backgroundColor = COLOR_WITH_RGB(arc4random()%255/255.0, arc4random()%255/255.0, arc4random()%255/255.0, 1);
    
    for (int i = 0; i < 500; i ++) {
        UILabel *label = [UILabel new];
        [self.view addSubview:label];
    }
}

// MARK: - WBCategoryListContentViewDelegate
- (UIView *)listView {
    return self.view;
}

@end
