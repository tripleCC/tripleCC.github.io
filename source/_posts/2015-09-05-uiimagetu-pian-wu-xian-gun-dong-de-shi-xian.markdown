---
layout: post
title: "UIImage图片无限滚动的实现"
date: 2015-06-29 20:34:41 +0800
comments: true
categories: 
---

当app需要切换显示的图片少时，可以使用创建多个UIImageView，来实现多个图片切换显示；但是在图片较多时，这种做法显得很耗内存。所以以下总结了一下自己知道的几个方法与实现，并做了一个简易的封装。

[获取演示代码](https://github.com/tripleCC/TPCPageScrollView)

[封装轮播控件的应用](https://github.com/tripleCC/GiftPick)（图片从网络加载）：<br>
![](/images/2015-09-13 10_54_13.gif)
<!--more-->
##采用三个UIImageView+UIScrollView
## 核心步骤
- 在图片显示完全（endDecelerating）时，重新设置三个UIImageView的图片内容
- 调整UIScrollView的偏移量，始终显示中间的UIImageView

如有图片1、2、3、4、5，默认存放图片5、1、2，显示中间图片1:<br>
1. 向后滚动，显示图片2<br>
2. 图片显示完全时，重新设置UIImageView中的图片为图片1、2、3<br>
3. 设置UIScrollView的偏移量，使其显示中间的UIImageView，即图片2<br>
4. 向后滚动，显示图片3<br>
5. 图片显示完全时，重新设置UIImageView中的图片为图片2、3、4<br>
6. 设置UIScrollView的偏移量，使其显示中间的UIImageView，即图片3

向前滚动同理。

如下图所示：

- 初始时显示图片1，然后向左滑动

![](/images/Snip20150531_26.png)

- 滑动完成时显示的是图片2

![](/images/Snip20150531_27.png)

- 在滑动完成时，修改UIImageView显示的内容如下图所示

![](/images/Snip20150531_28.png)

- 接着上一步，立即修改UIScrollView的偏移量，使其显示中间的UIImageView，即图片2

![](/images/Snip20150531_29.png)

如上，最终结果显示的都是最中间的UIImageView，看起来像是无限个UIImageView一样

## 核心代码
### 核心


另一种写法［更加简洁］：

.m
``` objc


#define kPageControlHeight 37
#define kDefaultDuration 2.0

@interface TPCPageScrollView() <UIScrollViewDelegate>

@property (weak, nonatomic) UIScrollView *scrollView;
@property (weak, nonatomic) UIPageControl *pageControl;

@property (weak, nonatomic) UIImageView *leftImageView;
@property (weak, nonatomic) UIImageView *currentImageView;
@property (weak, nonatomic) UIImageView *rightImageView;

@property (strong, nonatomic) NSTimer *timer;

@property (assign, nonatomic, getter=isAutoPaging) BOOL autoPaging;
@end

@implementation TPCPageScrollView

/**
 * 代码创建
 */
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // 创建控件并初始化
        [self setup];

        [self createImageView];
    }

    return  self;
}

/**
 * 从storyboard或者xib加载
 */
- (void)awakeFromNib
{
    // 创建控件并初始化
    [self setup];

    [self createImageView];
}

/**
 * 创建控件并初始化
 */
- (void)setup
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];

    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.pagingEnabled = YES;
    scrollView.scrollEnabled = YES;
    scrollView.delegate = self;

    // 取消弹簧效果，不然拖动会出现问题
    scrollView.bounces = NO;


    UIPageControl *pageControl = [[UIPageControl alloc] init];

    // 对于单个图片隐藏
    pageControl.hidesForSinglePage = YES;

    [self addSubview:scrollView];
    [self addSubview:pageControl];
    self.pageControl = pageControl;
    self.scrollView = scrollView;

    // 默认不开启自动切换图片
    self.autoPaging = NO;

    // 设置默认切图间隔
    self.pagingInterval = kDefaultDuration;
}

/**
 * 创建循环UIImageView
 */
- (void)createImageView
{
    UIImageView *leftImageView = [[UIImageView alloc] init];
    UIImageView *currentImageView = [[UIImageView alloc] init];
    UIImageView *rightImageView = [[UIImageView alloc] init];

    [self.scrollView addSubview:leftImageView];
    [self.scrollView addSubview:currentImageView];
    [self.scrollView addSubview:rightImageView];

    self.leftImageView = leftImageView;
    self.currentImageView = currentImageView;
    self.rightImageView = rightImageView;
}

- (void)setImages:(NSArray *)images
{
    _images = images;

    // 设置默认图片
    self.leftImageView.image = images[images.count - 1];
    self.currentImageView.image = images[0];
    self.rightImageView.image = images[1];

    self.leftImageView.tag = images.count - 1;
    self.currentImageView.tag = 0;
    self.rightImageView.tag = 1;

    //设置页数
    self.pageControl.numberOfPages = images.count;
    
    [self.scrollView setContentOffset:CGPointMake(imageViewW, 0)];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // 因为外界可以动态改变frame，所以有关frame的设置都在layoutSubviews中设置

    // 设置子控件的frame
    self.scrollView.frame = self.bounds;

    CGFloat imageViewW = self.scrollView.bounds.size.width;
    CGFloat imageViewH = self.scrollView.bounds.size.height;

    self.leftImageView.frame = CGRectMake(0, 0, imageViewW, imageViewH);
    self.currentImageView.frame = CGRectMake(imageViewW, 0, imageViewW, imageViewH);
    self.rightImageView.frame = CGRectMake(imageViewW * 2, 0, imageViewW, imageViewH);

    // 设置UIScrollView滚动内容大小
    self.scrollView.contentSize = CGSizeMake(imageViewW * 3, 0);

    // 设置UIPageControl默认位置
    CGFloat pageControlCenterX = self.bounds.size.width / 2.0;
    CGFloat pageControlCenterY = self.bounds.size.height - kPageControlHeight / 2.0;
    self.pageControl.center = CGPointMake(pageControlCenterX, pageControlCenterY);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // 设置UIPageControl的页码
    if (self.scrollView.contentOffset.x > self.scrollView.bounds.size.width * 1.5) {
        self.pageControl.currentPage = self.rightImageView.tag;
    } else if (self.scrollView.contentOffset.x < self.scrollView.bounds.size.width * 0.5) {
        self.pageControl.currentPage = self.leftImageView.tag;
    } else {
        self.pageControl.currentPage = self.currentImageView.tag;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // 手动拖拽切换更改内容
    [self updateContent];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    // 定时器切换更改内容
    [self updateContent];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.isAutoPaging) {
        [self stopTimer];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.isAutoPaging) {
        [self startTimer];
    }
}

- (void)setCurrentPageColor:(UIColor *)currentPageColor
{
    _currentPageColor = currentPageColor;

    self.pageControl.currentPageIndicatorTintColor = currentPageColor;
}

- (void)setOtherPageColor:(UIColor *)otherPageColor
{
    _otherPageColor = otherPageColor;

    self.pageControl.pageIndicatorTintColor = otherPageColor;
}

- (void)setPagingInterval:(NSTimeInterval)pagingInterval
{
    _pagingInterval = pagingInterval > 0 ? pagingInterval : kDefaultDuration;

    // 在开启自动切图的情况下，修改时间间隔会实时生效
    if (self.isAutoPaging) {
        [self startAutoPaging];
    }
}

/**
 * 以duration时间间隔，开启定时切换图片
 */
- (void)startAutoPagingWithDuration:(NSTimeInterval)pagingInterval
{
    // 先停止正在执行的定时器
    [self stopTimer];

    self.autoPaging = YES;
    self.pagingInterval = pagingInterval;
    [self startTimer];
}

/**
 * 开启自动切换图片
 */
- (void)startAutoPaging
{
    // 先停止正在执行的定时器
    [self stopTimer];

    self.autoPaging = YES;
    [self startTimer];
}

/**
 * 停止自动切换图片
 */
- (void)stopAutoPaging
{
    self.autoPaging = NO;
    [self stopTimer];
}

/**
 * 开启定时器
 */
- (void)startTimer
{
    // 注册定时器
    self.timer = [NSTimer timerWithTimeInterval:self.pagingInterval target:self selector:@selector(nextPage) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

/**
 * 关闭定时器
 */
- (void)stopTimer
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

/**
 * 下一张
 */
- (void)nextPage
{
    // 防止layoutSubviews中，第一次偏移量还没更改时就执行
    if (self.scrollView.contentOffset.x != 0) {
        // 移动到第三个UIImageView
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.bounds.size.width * 2, 0) animated:YES];
    }
}

/**
 * 更新图片和索引数据
 */
- (void)updateContent
{
    CGFloat scrollViewW = self.scrollView.bounds.size.width;

    if (self.scrollView.contentOffset.x > scrollViewW) {
        // 向前滚动，设置tag
        // 先设置左边的tag为当前图片tag后，才改变当前图片tag
        self.leftImageView.tag = self.currentImageView.tag;
        self.currentImageView.tag = self.rightImageView.tag;
        self.rightImageView.tag = (self.rightImageView.tag + 1) % self.images.count;

    } else if (self.scrollView.contentOffset.x < scrollViewW) {
        // 向后滚动，设置tag
        // 先设置右边的tag为当前图片tag后，才改变当前图片tag
        self.rightImageView.tag = self.currentImageView.tag;
        self.currentImageView.tag = self.leftImageView.tag;
        self.leftImageView.tag = (self.leftImageView.tag - 1 + self.images.count) % self.images.count;

    }

    // 设置图片
    self.leftImageView.image = self.images[self.leftImageView.tag];
    self.currentImageView.image = self.images[self.currentImageView.tag];
    self.rightImageView.image = self.images[self.rightImageView.tag];

    // 移动至中间的UIImageView
    [self.scrollView setContentOffset:CGPointMake(scrollViewW, 0) animated:NO];
}
@end

```

.h
``` objc

@interface TPCPageScrollView : UIView
/**
 * 图片
 */
@property (strong, nonatomic) NSArray *images;

/**
 * 当前页索引颜色
 */
@property (strong, nonatomic) UIColor *currentPageColor;

/**
 * 非当前页索引颜色
 */
@property (strong, nonatomic) UIColor *otherPageColor;

/**
 * 切换图片间隔
 * 在开启自动切图的情况下，修改时间间隔会实时生效
 */
@property (assign, nonatomic) NSTimeInterval pagingInterval;

/**
 * 开启自动切换图片
 * 会先停止上一次自动切图
 */
- (void)startAutoPaging;

/**
 * 停止自动切换图片
 */
- (void)stopAutoPaging;

/**
 * 以duration时间间隔，开启定时切换图片
 * 会先停止上一次自动切图
 */
- (void)startAutoPagingWithDuration:(NSTimeInterval)pagingInterval;
@end

```

##采用两个UIImageView＋UIScrollView
这个方法，和上面的方法原理是一样的。
假设使用UIV1表示始终显示的UIImageView，使用UIV2表示备份的UIImageView

- 首先，初始状态如下图所示，显示的是图片1（为了方便查看，我把UIImageView下移了，实际上和上面一排重合）<br>
  - 初始状态 <br>
![初始状态](/images/Snip20150630_26.png)<br>
- 这时候，向右边滚动（是滚，不是滑...），UIV2就立即显示图片2，这是，在屏幕可以看见图片1、2<br>
  - 向右滚动<br>
![向右滚动](/images/Snip20150630_27.png)
- 当滚动完成时只能看见图片2，如下
  - 滚动完成<br>
![滚动完成](/images/Snip20150630_28.png)
- 这是，将UIV1的图片换成图片2，同时将UIScrollView的偏移量设置到中间的位置（这个过程很快，实际看不出来有修改和移动）<br>
  - 修改图片<br>  
![修改图片](/images/Snip20150630_29.png)<br>
  - 修改偏移量<br>  
![修改偏移量](/images/Snip20150630_30.png)
- 向左滚动的情况<br>
  - 左滚动<br>  
![左滚动](/images/Snip20150630_31.png)
- 立即将UIV2的frame修改至最左边的位置，并设置图片为0<br>
  - 左滚动修改UIV2图片并移动<br>  
![左滚动修改UIV2图片并移动](/images/Snip20150630_32.png)
- 修改完成后情况<br>
  - 移动完成<br> 
![移动完成](/images/Snip20150630_33.png)
- 修改UIV1图片为图片0，并且设置UIScrollView偏移至中间位置<br>
  - 修改UIV1图片<br> 
![修改UIV1图片](/images/Snip20150630_37.png)<br>
  - 最终显示结果<br> 
![最终显示结果](/images/Snip20150630_38.png)

实现整体代码如下，有一个小技巧，使用tag标识对应的image，可以使代码更精简：

```objc
@interface TPCScrollViewByTwoImageView() <UIScrollViewDelegate>

@property (weak, nonatomic) UIScrollView *scrollView;
/**
 *  当前显示的view
 */
@property (weak, nonatomic) UIImageView *currentView;

/**
 *  备份的view（左右滑动时，显示的view）
 */
@property (weak, nonatomic) UIImageView *backupView;
@end

@implementation TPCScrollViewByTwoImageView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setUp];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [self setUp];
}

- (void)setUp
{
    // 创建需要的三个控件
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.pagingEnabled = YES;
    scrollView.bounces = NO;
    scrollView.delegate = self;
    scrollView.backgroundColor = [UIColor redColor];
    [self addSubview:scrollView];
    self.scrollView = scrollView;
    
    UIImageView *currentView = [[UIImageView alloc] init];
    [self.scrollView addSubview:currentView];
    self.currentView = currentView;
    
    UIImageView *backupView = [[UIImageView alloc] init];
    [self.scrollView addSubview:backupView];
    self.backupView = backupView;
    
    self.backgroundColor = [UIColor greenColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.scrollView.frame = self.bounds;
    
    CGFloat imageViewW = self.bounds.size.width;
    CGFloat imageViewH = self.bounds.size.height;
    // 设置scrollView的内容大小
    self.scrollView.contentSize = CGSizeMake(imageViewW * 3, 0);
    
    // 设置imageView的frame
    self.currentView.frame = CGRectMake(imageViewW, 0, imageViewW, imageViewH);
    self.backupView.frame = CGRectMake(imageViewW * 2, 0, imageViewW, imageViewH);
}

- (void)setImages:(NSArray *)images
{
    _images = images;
    
    // 设置默认图片
    self.currentView.image = images[0];
    self.backupView.image = images[1];
    
    // 设置tag为图片下标
    self.currentView.tag = 0;
    self.backupView.tag = 1;
    
    self.scrollView.contentOffset = CGPointMake(imageViewW, 0);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offsetX = scrollView.contentOffset.x;
    
    // 根据偏移量，设置backView的图片，并修改其图片下标
    if (offsetX < self.bounds.size.width) {
        self.backupView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        self.backupView.tag = (self.currentView.tag - 1 + self.images.count) % self.images.count;
        self.backupView.image = self.images[self.backupView.tag];
    } else if (offsetX > self.bounds.size.width) {
        self.backupView.frame = CGRectMake(self.bounds.size.width * 2, 0, self.bounds.size.width, self.bounds.size.height);
        self.backupView.tag = (self.currentView.tag + 1) % self.images.count;
        self.backupView.image = self.images[self.backupView.tag];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat offsetX = scrollView.contentOffset.x;
    
    // 停止时，设置偏移量为currentView所在位置
    scrollView.contentOffset = CGPointMake(self.bounds.size.width, 0);
    
    // 实际上没有换页，就返回
    if (offsetX < self.bounds.size.width * 1.5 && offsetX > self.bounds.size.width * 0.5) {
        return;
    }
    
    // 根据backView的image，来进行图片更换
    self.currentView.image = self.backupView.image;
    
    // 设置当前图片下标
    self.currentView.tag = self.backupView.tag;
}
```
##使用UICollectionView
因为UICollectionView有cell重用机制，所以只需要两个cell，即可完成上面的功能，内存压力也不会太大。

- 设置UICollectionView的属性
```objc
UICollectionViewFlowLayout *collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
   // 设置cell间距
    collectionViewLayout.minimumLineSpacing = 0;
  // 设置尺寸为view的大小
    collectionViewLayout.itemSize = self.bounds.size;
  // 设置为水平滑动
    collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:collectionViewLayout];
    
    collectionView.delegate = self;
    collectionView.dataSource = self;
   // 设置页切换允许
    collectionView.pagingEnabled = YES;
    collectionView.bounces = NO;
```
- 对cell进行注册
```
  [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"tpc"];
```
- 然后根据外界传入的图片，设置数据源方法即可实现了

```
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.images.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tpc" forIndexPath:indexPath];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.images[indexPath.row]];
    imageView.frame = self.bounds;
    cell.backgroundView = imageView;
    
    return cell;
}
```

##总结
对于前面两种方法，我使用了UIImageView的tag来记录对应图片的下标，所以也省去了一个变量。
