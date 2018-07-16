---
layout: post
title: "UINavigationBar属性小结及返回按钮更改"
date: 2015-07-23 20:17:32 +0800
comments: true
categories: ios
---

## UINavigationBar属性

- 如果想统一设置，可以通过以下方法，获取当前类下的所有对象的导航条，然后进行设置

```objc
[UINavigationBar appearanceWhenContainedIn:self, nil];
```

- 背景图片<br>
![](/images/Snip20150724_4.png)

```objc
  // barMetrics需要设置成UIBarMetricsDefault
  - (void)setBackgroundimages:(UIimages *)backgroundimages forBarMetrics:(UIBarMetrics)barMetrics
```
- 背景阴影图片<br>
![](/images/Snip20150724_5.png)

```objc
  @property(nonatomic,retain) UIimages *shadowimages
```
<!--more-->
- 隐藏底部1px下划线（[详细讨论](http://stackoverflow.com/questions/19226965/how-to-hide-ios7-uinavigationbar-1px-bottom-line)）<br>
![](/images/Snip20151116_1.png)

```objc
// 注意，阴影生效，必须要有背景图片
[self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
```
以下方法可以在不设置背景图片的情况下实现：

```objc
// 传入navigationBar可以找出下划线控件
- (UIImageView *)findHairlineImageViewUnder:(UIView *)view {
    if ([view isKindOfClass:UIImageView.class] && view.bounds.size.height <= 1.0) {
        return (UIImageView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIImageView *imageView = [self findHairlineImageViewUnder:subview];
        if (imageView) {
            return imageView;
        }
    }
    return nil;
}
```

- 背景颜色<br>
![](/images/Snip20150724_6.png)

```objc
  @property(nonatomic,retain) UIColor *barTintColor
```

- 标题文字属性<br>
![](/images/Snip20150724_10.png)

```objc
  @property(nonatomic,copy) NSDictionary *titleTextAttributes;
```
- 系统类型按钮文字颜色<br>
![](/images/Snip20150724_9.png)

```objc
  @property(nonatomic,retain) UIColor *tintColor
```
- 返回按钮图片<br>
![](/images/Snip20150724_11.png)

```objc
  // 必须要两个都设置，并且图片要设置成不渲染
  @property(nonatomic,retain) UIimages *backIndicatorimages;
@property(nonatomic,retain) UIimages *backIndicatorTransitionMaskimages;
```
- 标题垂直偏移<br>
![](/images/Snip20150724_12.png)

```objc
  - (void)setTitleVerticalPositionAdjustment:(CGFloat)adjustment forBarMetrics:(UIBarMetrics)barMetrics
```

## 返回按钮更改

系统原装效果:<br>
![](/images/Snip20150724_13.png)<br>

如果有以下需求:

- 去除上面返回按钮上“我是标题”字样，并设置返回图片为白色

## 分析

- 图片修改
    - 方式1：设置返回图片颜色
    - 方式2：直接设置返回图片
    - 方式3：使用按钮覆盖返回图片(这种方式会使返回箭头图片和左边距离加大，但可以用取巧的方式调整)
- 文字修改
    - 方式1：设置控制器navigationItem的backBarButtonItem显示文字为""
    - 方式2：设置返回按钮文字偏移量，使其移出屏幕
    - 方式3：采用控制器navigationItem的leftBarButtonItem进行覆盖
    
## 解决

综合以上说明，这里给出三种方式(都是针对的自定义UINavigationController)：

  - 方式1:在`-pushViewController:animated:`中设置文字 ，在`+initialize`方法中设置返回图片或改变返回图片颜色
    - 注意导航栏对图片的渲染
  
```objc
  - (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    viewController.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleDone target:nil action:nil];

    [super pushViewController:viewController animated:animated];
}
```
  
```objc
    // 获取特定类的所有导航条
    UINavigationBar *navigationBar = [UINavigationBar appearanceWhenContainedIn:self, nil];
    
    // 方式1：使用自己的图片替换原来的返回图片
    navigationBar.backIndicatorImage = [UIImage imageNamed:@"NavBack"];
    navigationBar.backIndicatorTransitionMaskImage = [UIImage imageNamed:@"NavBack"];

    // 方式2：设置返回图片颜色
    navigationBar.tintColor = [UIColor whiteColor];
```
  
  - 方式2:在`+initialize`方法中设置所有返回按钮文字的偏移量，其他设置和方式1一致
  
```
  [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(0, -100) forBarMetrics:UIBarMetricsDefault];
```
  
  - 方式3.重写`-pushViewController:animated:`方法,使用控制器的`navigationItem的leftBarButtonItem`覆盖返回按钮
    - 需要判断是否为根控制器，如果是根控制器就不添加
      - 导航控制器的`viewControllers.count`不为0即表示传入的为非根控制器

```
    - (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (self.viewControllers.count != 0) {
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"NavBack"] style:UIBarButtonItemStyleDone target:self action:@selector(back)];
    }

    [super pushViewController:viewController animated:animated];
}
```

```
    - (void)back
	{
    [self popViewControllerAnimated:YES];
    }
```

## 方案对比

- 方案1和方案2改动较小，对系统自带的返回功能无影响。<br>
- 方式3灵活性最高，但是会`使系统的滑动返回失效`，需要自己实现，具体实现参照[forkingdog全屏手势分类](https://github.com/forkingdog/FDFullscreenPopGesture)<br>
- 方式3还会使按钮更加偏向右边：

![](/images/Snip20150722_10.png)<br>
通过以下方式可以使按钮向左边靠：
![](/images/Snip20150722_11.png)<br>
- 采用customView，`添加自己定义的UIButton`<br>

```
...
// 返回按钮内容左靠
button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

// 让返回按钮内容继续向左边偏移10
button.contentEdgeInsets = UIEdgeInsetsMake(0, -10, 0, 0);
...
viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
```