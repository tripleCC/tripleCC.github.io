---
layout: post
title: "闲谈 IGListKit"
description: IGListKit, SectionController, 数据驱动, 构建表单, RETableViewManager, 固化样式, 复用单元, 分离业务代码
date: 2017-06-23 16:13:46 +0800
comments: true
categories: ios
---
IGListKit 是 Instagram 在 16 年出品的一款针对 UICollectionView 的***数据驱动***框架，旨在帮助开发者更加快速、灵活地构建列表页面。 

现存的绝大部分 Objective-C 框架，在集成进 Swift 项目中后，编写的代码依然会透出一股浓浓的 Objective-C 味，总感觉不纯正。而 IGListKit 虽然使用 Objective-C/C++ 开发，但是很好地照顾到了日渐增多的 Swift 开发者，不仅提供了大量 Swift 编写的 Demo （绝大部份），而且在 3.0.0 版本之后去除了 `IG` 前缀，更好地兼容了现版本 Swift 简洁的代码风格。所以，不管是 Swift 项目，还是 Objective-C 项目，引入 IGListKit 都是个不错的选择， 一来方便***分离***业务代码以降低复杂度，再者可以更好地编写***粒度更大***的复用单元目的，更多好处，只能在使用中体验了。



<!--more-->
## 初识 IGListKit
去年初次使用 IGListKit 时，除了数据驱动，它对传统 UICollectionView 所做的封装方式，以及流畅的编写体验同样让我感到惊艳和意外。

下面是 IGListKit 的层级结构图：

```

									|---- Cell
		|---- SectionController ----|
		|							|---- Cell		
		|
	    |							|---- Cell
Adpter|---- SectionController ----|
		|							|---- Cell
		|
		|							|---- Cell
		|---- SectionController ----|
									|---- Cell
```	

刚入手 IGListKit ，可能会感觉这种分层似曾相识 ------ UITableView 的 dataSource：

```
                                  |---- Cell
                |---- Section ----|
                |                 |---- Cell		
                |
                |                 |---- Cell
dataSource  |---- Section ----|
                |                 |---- Cell
                |
                |                 |---- Cell
                |---- Section ----|
                                  |---- Cell
```	

但是上面的分层只是概念上的，并没有直接在 UITableViewSource ，也就是在代码的层面体现出来，编写业务代码时，Cell 和 Section 的 View 只是分散在两个不同代理方法中。如果要进行分层，需要手动对 UITableView 进行一层封装。 

IGListKit 恰好替开发者封装了这层接口，在编写代码时， Cell 是挂在 SectionController 类中的。当存在多个不同类型的 SectionController 时，每个 SectionController 类管理属于自己的 Cell，这样做有利于开发者进行业务代码的分离，更进一步讲，有利于大粒度单元的复用。

IGListKit 十分强调***页面粒度的细化***，所以 SectionController ***只能***挂载一个 unique Object ，然后根据这个 Object 去生成一个或多个 Cell 。一般情况下，一个（种） Object 只会填充一个（种） Cell ，一个（种） Cell 的业务由一个 SectionContoller 进行管理。 SectionController 还对应了一个 supplementaryViewSource ，用以提供 Section 的头尾视图。

不过也正是因为这种严格的机制，加上 `objectsForListAdapter:` 返回的必须是承载 unique 的 Object 的数组，通常也就是扁平的一维数组，导致 IGListKit 无法像 UITableView 的 dataSource 一样，通过嵌套的数据对象数组来描述 Section 。这也就造成了 IGListKit 在构建某些 Section 边界比较模糊的界面时，需要开发者做出比原生控件更多的配置和包装才能实现。比如以下情况：

```objc
class Message {
    let timestamp: String
    let text: String
    
    init(timestamp: String, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}
```
如果要求列表以相同的 timestamp 为基准来划分 Section ，并在 Section 头部加上时间的 supplementaryView ，用 IGListKit 实现就会有点麻烦。对于多个不同 SectionController 的组合，虽然 IGListKit 专门提供了StackedSectionController ，不过同样的，StackedSectionController 对应的还是一个 Object，换句话说，其下多个 SectionController 绑定了同个 Object 。 

不过瑕不掩瑜，IGListKit 还是提供了很多好用的特性，不管是 WorkRange，还是数据驱动的更新机制，都是值得一试的理由。

## 使用 IGListKit 构建表单
前面说的是可复用性强的列表页面，那么元素可复用性较差的表单界面 IGListKit 能够规避使用原生控件 dataSource 时 `if else` 判断过多的情况么？

目前的答案是不能，SectionController 只是打散了 Section 层面的业务逻辑，当一个 SectionController 中有许多种不同类型的 Cell 时，其表现出来的业务复杂度和使用原生控件的 dataSource 并没有显著差别。不过我们可以参照 RETableViewManager 给 IGListKit 再做一层简易的包装。

[RETableViewManager](https://github.com/romaonthego/RETableViewManager) 也是一个数据驱动的库，只不过针对的是 UITableView ，但是此数据驱动和 IGListKit 的数据驱动还是有比较明显的区别的。

在我看来，RETableViewManager 的强调的是***展示固化样式***，通过绑定各式各样的 Item 和 Cell ，来达到数据驱动的目的，开发者只要操纵 Item 即可构建界面。而 IGListKit 的强调的则是 ***操作Object 的唯一性***，利用这个唯一性对特定 UICollectionView 进行增删改，凡是可以获取到 Object 的地方，就可以摒弃以前通过 NSIndexPaths 操作 UICollectionView 的方式，不过开发者还是需要和 Cell 打交道。


## 包装 IGListKit
以下代码，可以在 [TBVListAdapterManager](https://github.com/tobevoid/TBVListAdapterManager) 中查看。

在包装 IGListKit 之前，先来看下 RETableViewManager 的层级结构：

```
                                      |---- Item ~~~~ Cell
                    |---- Section ----|
                    |                 |---- Item ~~~~ Cell		
                    |
                    |                 |---- Item ~~~~ Cell
TableViewManager|---- Section ----|
                    |                 |---- Item ~~~~ Cell
                    |
                    |                 |---- Item ~~~~ Cell
                    |---- Section ----|
                                      |---- Item ~~~~ Cell
```

上方的 Item 和 Cell 是互相绑定关系，在获取到数据对象 Object 后，可以通过设置 Item 去渲染 Cell。也就是说， Item 和 Object 是一对一，甚至是多对一的关系，这个和 IGListKit 刚好切合，因为它的 Cell 和 Object 就是一对一或者多对一的关系。结合上图， RETableViewManager 的 Section 可以对应多个 Object ，而 IGListKit 的 SectionController 只能对应一个 Object ，这就造成了无法将 SectionControler 直接封装成 Section 的窘境。


事实上，我更愿意把 SectionControler 描述成一组 Cell 的集合，而非传统意义上的 Section 。既然 SectionControler 和 Object 是一对一关系，那么 SectionController 本身是否也可以遵守 `IGListDiffable` 而成为一个 unique Object呢 ？从这个角度出发，可以初步看下封装后的层级结构：

```
                                                          |---- Item ~~~~ Cell
                                      |---- ItemBunch ----|         
                                      |                   |---- Item ~~~~ Cell
                                      |
                    |---- Section ----|                   
                    |                 |			
                    |                 |                   |---- Item ~~~~ Cell
                    |                 |---- ItemBunch ----| 
                    |                                     |---- Item ~~~~ Cell        
                    |
                    |                                     
AdapterManager  |
                    |
                    |
                    |
                    |                                     |---- Item ~~~~ Cell
                    |                 |---- ItemBunch ----|         
                    |                 |                   |---- Item ~~~~ Cell
                    |                 |                  
                    |---- Section ----|                   
                                      |			
                                      |                   |---- Item ~~~~ Cell
                                      |---- ItemBunch ----| 
                                                          |---- Item ~~~~ Cell   
```

接下来看下具体的接口定义， ItemBunch 接口如下：

```objc
NS_ASSUME_NONNULL_BEGIN
@class TBVListSection;
@class TBVListItemBunch;
@class TBVListItem;

NS_SWIFT_NAME(ListItemBunchViewSource)
@protocol TBVListItemBunchViewSource <NSObject>
@required
- (NSArray <NSString *> *)supportedElementKindsForBunch:(TBVListItemBunch *)bunch;
- (__kindof UICollectionReusableView *)bunch:(TBVListItemBunch *)bunch viewForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index;
- (CGSize)bunch:(TBVListItemBunch *)bunch sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index;
@end

NS_SWIFT_NAME(ListItemBunch)
@interface TBVListItemBunch : IGListSectionController <IGListDiffable> {
    @package
    __weak TBVListSection *_associatedSection;
    __weak id <TBVListItemBunchViewSource> _bunchViewSource;
}

@property (nullable, weak, nonatomic, readonly) TBVListSection *associatedSection;
@property (nullable, strong, nonatomic, readonly) NSArray *items;
@property (assign, nonatomic, readonly) NSInteger index;

- (instancetype)initWithItem:(nullable TBVListItem *)item;

- (void)addItem:(nonnull TBVListItem *)item;
- (void)removeItem:(nonnull TBVListItem *)item;

- (void)reload;
- (void)reloadAnimated:(BOOL)animated;
- (void)reloadAnimated:(BOOL)animated completion:(nullable void (^)(BOOL finished))completion;
@end
NS_ASSUME_NONNULL_END
```

Item 的接口如下：

```objc
NS_ASSUME_NONNULL_BEGIN
@class TBVListItemBunch;
@class TBVListItem;

NS_SWIFT_NAME(ListItemSelectBlock)
typedef void (^TBVListItemSelectBlock)(TBVListItem * _Nonnull item);

NS_SWIFT_NAME(ListItem)
@interface TBVListItem : NSObject {
    @package
    __weak TBVListItemBunch *_associatedBunch;
}

@property (nullable, weak, nonatomic, readonly) TBVListItemBunch *associatedBunch;
@property (assign, nonatomic) CGSize cellSize;
@property (assign, nonatomic, readonly) NSInteger index;
@property (nullable, copy, nonatomic) TBVListItemSelectBlock selectBlock;

- (void)reload;
- (void)reloadAnimated:(BOOL)animated;
- (void)reloadAnimated:(BOOL)animated completion:(nullable void (^)(BOOL finished))completion;
@end
NS_ASSUME_NONNULL_END
```

Section 的接口如下：

```objc
NS_ASSUME_NONNULL_BEGIN
@class TBVListAdapterManager;
@class TBVListItemBunch;
@class TBVListSection;

NS_SWIFT_NAME(ListSection)
@interface TBVListSection : NSObject {
    @package
    __weak TBVListAdapterManager *_associatedManager;
}

@property (nullable, weak, nonatomic, readonly) TBVListAdapterManager *associatedManager;
@property (nullable, strong, nonatomic, readonly) NSArray <TBVListItemBunch *> *itemBunches;
@property (assign, nonatomic, readonly) NSInteger index;

@property (nullable, strong, nonatomic) TBVListSectionConfiguration *headerConfiguration;
@property (nullable, strong, nonatomic) TBVListSectionConfiguration *footerConfiguration;

- (void)addItemBunch:(nonnull TBVListItemBunch *)bunch;
- (void)removeItemBunch:(nonnull TBVListItemBunch *)bunch;

- (void)reload;
@end
NS_ASSUME_NONNULL_END
```
至此，对于 IGListKitExamples 的 ObjcDemoViewController ，我可以重新用这套包装，去实现上文所说的 Section 边界比较模糊的的场景：

```objc
TBVListAdapterManager *manager = [[TBVListAdapterManager alloc] initWithAdapter:self.adapter];
[manager registerItems:@[TBVS(InteractiveItem), TBVS(PhotoItem), TBVS(UserInfoItem), TBVS(CommandItem)]];
for (NSInteger i = 2; i > 0; i--) {
    {
        TBVListSection *section = [TBVListSection new];
        section.headerConfiguration = [[TBVListSectionConfiguration alloc]
                                       initWithSupplementarySize:CGSizeMake(100, 20)
                                       reusableClass:[TBVCollectionReusableView class]
                                       configureBlock:^(TBVListSection *section, TBVCollectionReusableView *reusableView) {
                                           reusableView.textLabel.text = @"2017-01-22 12:23:44";
                                       }];
        [manager addSection:section];
        
        for (Post *p in self.data) {
            TBVListItemBunch *bunch = [TBVListItemBunch new];
            [section addItemBunch:bunch];
            
            {
                UserInfoItem *item = [UserInfoItem new];
                item.selectBlock = ^(TBVListItem * _Nonnull item) {
                    item.cellSize = CGSizeMake(item.cellSize.width, arc4random_uniform(100));
                    [item reload];
                };
                [bunch addItem:item];
            }
            {
                PhotoItem *item = [PhotoItem new];
                item.selectBlock = ^(TBVListItem * _Nonnull item) {
                    item.cellSize = CGSizeMake(item.cellSize.width, arc4random_uniform(100));
                    
                    [item.associatedBunch reload];
                };
                [bunch addItem:item];
            }
            {
                InteractiveItem *item = [InteractiveItem new];
                item.selectBlock = ^(TBVListItem * _Nonnull item) {
                    item.cellSize = CGSizeMake(item.cellSize.width, arc4random_uniform(100));
                    [item.associatedBunch.associatedSection reload];
                };
                [bunch addItem:item];
            }
            
            for (NSString *c in p.comments) {
                TBVCommandItem *item = [TBVCommandItem new];
                item.commant = c;
                [bunch addItem:item];
            }
        }
    }
}

self.manager = manager;
[self.manager reload];
```

对于上述固化样式类的数据驱动模型，我认为实现***"自治"***是核心。这就要求通过 Item 可以访问 ItemBunch， 通过 ItemBunch 可以访问 Section，Section、AdapterManger 同理 （链表式的访问）。  这样做的好处是，可以通过 Item 、ItemBunch 和 Section 直接刷新自身，而不需要去手动获取 tableView / collectionView 再结合 NSIndexPaths 去刷新对应条目，让***所有的变动通过操作数据完成***；而且针对复杂业务，我还是可以很方便地回到 IGListKit 利用 SectionController 处理业务的那种方式，将业务分散到 Section 子类中。

## 小结

IGListKit 强调的***页面粒度的细化***恰恰是我所推崇的，一旦样式积木多了之后，构造页面的方式就具备了无限的可能性。对于部分展示逻辑偏多、交互偏少的 App 来说，利用固化样式来精简业务代码是个不错的选择。虽然“固化”一词看起来和“灵活”相反，但事实上并非如此，一定程度上的固化恰恰能让界面的编写更加灵活。

如果将固化的样式想像成大粒度的 HTML 标签，那么就可以把 App 当作一个移动端的浏览器，而让后台下发固化样式以堆砌界面。

另外，在构造样式 / Item 的时候，***面向接口编程***能给后期扩展带来不小的灵活性。换句话说，多用 Protocol ,少用继承。

## 参考

[IGListKit](https://instagram.github.io/IGListKit/)<br>
[IGListKit Tutorial: Better UICollectionViews](https://www.raywenderlich.com/147162/iglistkit-tutorial-better-uicollectionviews)<br>
[从 Instagram 开源 IGListKit 聊聊 iOS 开发趋势](https://imtx.me/archives/2091.html)<br>
[精益创业实践——食色App背后的三个小故事](http://www.infoq.com/cn/presentations/three-little-stories-behind-the-shise-app)<br>
