---
layout: post
title: "利用runtime兼容老代码小记"
date: 2016-12-05 21:50:14 +0800
comments: true
categories: objective-c
---
通常来说，在项目的初期，因为各种原因，要么人力不够，要么项目周期过紧，会产生难以维护、阅读性较差的代码。而这种代码，我习惯称之为“老代码”。就比如现在手上的项目，初期是由一个被迫转到 `iOS` 的后端 `java` 哥们写的，所以工程里面到处都可以看见 `java` 的一些编码风格，比如模型以 `Vo` 结尾、接口以 `I` 开头等，甚至转场动画都是简单粗暴地通过 `view` 叠加再辅以动画实现的。“老代码”是项目特定时间段的产物，因此，也不能把锅全部推给写这些代码的人。不过前人埋坑，后人总得填啊。

好了，吐槽完毕，开始正题。
<!--more-->

当前项目的业务里面有各种可供筛选的条件，比如分类、通道、类别等。“老代码”是这样实现相关功能的：

- 每种筛选条件都创建一个模型，它们的父类并没有统一
- 分类存在父子分类，所以有一个 ItreeNode 协议来规范分类模型
- 通道和类别等其他条件是没有父子分类的，不过“老代码”为了能让视图统一根据 ItreeNode 来渲染界面，依然让它们遵守 ItreeNode ，这里暂且不论这样做是否科学
- 后台返回的数据中没“全部”条件，需要前端自己添加，“老代码”以 -1 作为“全部”条件的 id ，但是没有统一入口，外部都是手动创建模型，赋值 id 属性。
- 筛选 UI 控件使用 id 保证条件的唯一性，而获取 id 是通过 ItreeNode 的 obtainItemId 方法


做为一个比较懒的人，做新页面的时候，我肯定不想每次都手动创建一次“全部”条件，至少不能每次都创建不一样的模型，只为了给当前筛选控件添加“全部”条件。更进一步讲，能不能创建一个如下的 `NSArray` 分类：

```objc
- (NSArray <id<ITreeNode>> *)tdf_prefixAllTypeWithName:(NSString *)name;

```
这样针对条件数组，我只需要这样调用就可以了：

```objc
// name可以是@“全部分类"、@“全部通道”或者其他筛选条件
[categories tdf_prefixAllTypeWithName:name]
```
那么问题来了，要怎么做才能让不同筛选的条件都能使用同一个“全部”接口呢？

首先，我不想用 `if-else` 或者 `switch-if` 的，虽然简单粗暴，但是以后如果要添加新的条件类型的话，还需要修改这个判断分支，不够优雅。
既然筛选的UI控件使用的是 `ItreeNode` 方法获取，那我直接创建一个 `AllType` 好了：

```objc
@interface TDFTreeNodeAllType : Base <ITreeNode>
/** 类型名（默认‘全部分类’） */
@property (assign, nonatomic) NSString *name;

+ (instancetype)node;
/** 通过这个方法来比较是否是全部分类 */
- (BOOL)isEqual:(id <ITreeNode>)object;
@end

@implementation TDFTreeNodeAllType
+ (instancetype)node {
    TDFTreeNodeAllType *node = [[TDFTreeNodeAllType alloc] init];
    node.id = TDFSilverBulletId;
    return node;
}
- (BOOL)isEqual:(id <ITreeNode>)object {
    return [[self obtainItemId] isEqualToString:[object obtainItemId]];
}
- (NSString *)obtainItemId {
    return self.id;
}
- (NSString *)obtainItemName {
    return self.name
}
...
@end


@implementation NSArray (AllType)
- (NSArray <id<ITreeNode>> *)tdf_prefixAllTypeWithName:(NSString *)name {
    NSAssert([self.firstObject conformsToProtocol:@protocol(ITreeNode)], @"items should conform to ITreeNode");
    
    NSMutableArray *result = self.mutableCopy;
    if (![[self.firstObject obtainItemId] isEqualToString:TDFSilverBulletId]) {
        TDFTreeNodeAllType *all = [TDFTreeNodeAllType node];
        all.name = name;
        [result insertObject:all atIndex:0];
    }
    return result;
}
@end
```
搞定收工！

但是稍微跑下后，我发现了一个蛋疼的问题：外部要使用这些条件类型特定属性的时候，程序会崩溃，因为 `TDFTreeNodeAllType` 找不到对应的方法。
这时，我第一个想到的就是动态创建一个“全部”类型对象：

```objc
- (NSArray <id<ITreeNode>> *)tdf_prefixAllTypeWithName:(NSString *)name {
    NSAssert([self.firstObject conformsToProtocol:@protocol(ITreeNode)], @"items should conform to ITreeNode");
    
    NSMutableArray *result = self.mutableCopy;
    if (![[self.firstObject obtainItemId] isEqualToString:TDFSilverBulletId]) {
        Class class = [self.firstObject class];
        id <ITreeNode> node = [[class alloc] init];
        
			???????????????????????????????????????????
		
        [result insertObject:node atIndex:0];
    }
    return result;
}
```
但是这里我怎么让 `node` 成为全部类型对象呢？实际上我并不能直接让 `node` 的 `obtainItemId` 方法返回 `-1` ，也不能通过 `method_setImplementation` 或者 `method_exchangeImplementations` 修改 `obtainItemId` 的实现，因为会影响到类原本对于这个方法的实现。

绕了一圈，还是回到了单独创建一个模型 `TDFTreeNodeAllType` 表示“全部”条件的方案。现在明确要解决的问题是：如何让外部调用 `TDFTreeNodeAllType` 没有，筛选条件模型有的方法，还可以不崩溃？嗯，答案在消息转发相关的三步骤。

首先要记录筛选条件的 `Class` ：

```objc
@interface TDFTreeNodeAllType : Base <ITreeNode>
/** 当前类型对应的类，保证同样的操作不会崩溃 */
@property (assign, nonatomic) Class targetClass;

/** 类型名（默认‘全部分类’） */
@property (assign, nonatomic) NSString *name;

+ (instancetype)node;
/** 通过这个方法来比较是否是全部分类 */
- (BOOL)isEqual:(id <ITreeNode>)object;
@end

@implementation NSArray (AllType)
- (NSArray <id<ITreeNode>> *)tdf_prefixAllTypeWithName:(NSString *)name {
    NSAssert([self.firstObject conformsToProtocol:@protocol(ITreeNode)], @"items should conform to ITreeNode");
    
    NSMutableArray *result = self.mutableCopy;
    if (![[self.firstObject obtainItemId] isEqualToString:TDFSilverBulletId]) {
        TDFTreeNodeAllType *all = [TDFTreeNodeAllType node];
        all.targetClass = [self.firstObject class];
        all.name = name;
        [result insertObject:all atIndex:0];
    }
    return result;
}
@end
```
在消息转发前，可以通过重载 `forwardingTargetForSelector` 知悉当前要调用的方法。所以只要在这个方法里面判断 `TDFTreeNodeAllType` 是否存在此 `SEL` ，没有的话返回上面保存 `Class` 创建的对象就可以了：

```objc
- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (![self respondsToSelector:aSelector]) {
        NSAssert(self.targetClass, @"target class should't be nil in order to avoiding forwarding Invocation");
        return [[self.targetClass alloc] init];
    }
    return [super forwardingTargetForSelector:aSelector];
}
```
再给`NSObject`添加一个判断是否为“全部”条件的分类：

```objc
@implementation NSObject (AllType)
- (BOOL)tdf_isAllType {
    NSAssert([self conformsToProtocol:@protocol(ITreeNode)], @"object should confirm ITreeNode");
    return [[(id <ITreeNode>)self obtainItemId] isEqualToString:TDFSilverBulletId];
}
@end
```
这样一来，添加和使用“全部”条件就非常方便了。

虽然很多论调都说 `runtime` 工作上用的场景非常之少，面试问这些的没啥用，但是个人感觉还是要知道一些的。因为假如真的遇到一些难以通过平常手段搞定的需求的话， `runtime` 能给开发者带来一些别样的灵感。
