---
layout: post
title: "UITableView右侧滚动标签"
date: 2015-09-01 20:30:39 +0800
comments: true
categories: ios
---
看到有些APP在tableView右侧增加了一个滚动标签，并且显示滑条所指向的cell的部分数据。这里写下自己的想法，实现还是简单的。

#### 效果图

![](/images/2015-08-29 21_16_47.gif)<br>
<!--more-->

#### 需求

需求点大意是在tableView的右侧实现一个类似标签索引的东西，标签索引显示对应cell的时间。

#### 解决方法

想到的方法一：

  - 刚开始打算自己创建一个UILabel索引标签，然后监听tableView的contentOffset来实现索引标签的移动：

```objc
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	// 在这里根据scrollView.contentOffset.y来改变标签索引的坐标
	// contentSize的高度，和屏幕高度是成固定比例的，所以可以计算出来
}
```
后来感觉这样太麻烦，于是就打算监听scrollview内部的导航view决定索引标签的移动。由于是scrollView的内部控件，所以就通过断点的方式获取控件的成员变量名:<br>
![](/images/Snip20150829_4.png)

看出成员变量名如下：<br>
![](/images/Snip20150829_3.png)

由此可以引出方法二和三。

方法二：

  - 还是采用创建UILabel，不过是加到控制器的view上，然后根据其中的_verticalScrollIndicator的左边，来进行相应的移动。
  
由于此标签索引不需要交互，所以我采用了方法三。<br>
方法三：

  - 将创建的UILabel添加到_verticalScrollIndicator上，成为它的子控件。然后通过indexPathForRowAtPoint:获取对应的cell的行号。因为_verticalScrollIndicator本身是和tableView在同一个坐标系，所以也不需要做转换。
  
主要代码如下：

```objc
@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) UILabel *indicatorView;
@property (weak, nonatomic) UIView *scrollIndicator;
@end

static NSString *const reuseIndentifier = @"testCell";
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = 150;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 200;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIndentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIndentifier];
    }
    cell.backgroundColor  = [UIColor colorWithRed:arc4random_uniform(255)/255.0 green:arc4random_uniform(255)/255.0 blue:arc4random_uniform(255)/255.0 alpha:0.5];
    cell.textLabel.text = [NSString stringWithFormat:@"just a function test--%ld!", indexPath.row];
    
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    UITableView *tableView = (UITableView *)scrollView;
    
    // 在这里根据_verticalScrollIndicator的中点，来获取对应的cell行号，从而可以获取对应行的数据来进行显示
    self.indicatorView.text = [NSString stringWithFormat:@"%ld", [tableView indexPathForRowAtPoint:self.scrollIndicator.center].row];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	// 这里注意要在点击时获取，如果在view加载完成时设置标签索引的中点，那么获取的_verticalScrollIndicator的frame是不对的
    if (!self.indicatorView) {
        self.scrollIndicator = [self.tableView valueForKey:@"verticalScrollIndicator"];
        
        UILabel *indicatorView = [[UILabel alloc] initWithFrame:CGRectMake(-50, 0, 50, 20)];
        indicatorView.backgroundColor = [UIColor orangeColor];
        
        CGPoint center = indicatorView.center;
        center.y = self.scrollIndicator.bounds.size.height * 0.5;
        indicatorView.center = center;
        
        [self.scrollIndicator addSubview:indicatorView];
        self.indicatorView = indicatorView;
    }
}

@end
```




