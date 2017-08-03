---
layout: post
title: "Objective-C 消息转发应用场景摘录"
date: 2017-07-09 14:20:30 +0800
comments: true
categories: 
---


说起 Objective-C runtime 在实际项目中的应用，可能很多人第一时间联想到的是黑魔法 method swizzling 、 associated objects 、 KVC / KVO 以及各种灵活的 runtime api 。这几种技术在开发过程中或多或少都会涉及到 ，也的确为开发者立下了汗马功劳，尤其在解决一些棘手问题时，屡试不爽。不过同样是 runtime 重要组成部分的**消息转发**却较少听人提及，这篇文章就来扒一扒它在不同应用场景中的精彩表现。

<!--more-->

<!-- ## 目录

1、简说消息转发 <br>
2、简化代理方法的调用 <br>
3、部分代理方法转发<br>
4、多播代理<br>
5、代理强引用转弱引用<br>
6、NSUndoManager 中的应用<br>
7、依靠协议的依赖注入<br>
8、小结<br>
9、参考<br> -->

## 简说消息转发

在开始之前，先简单温习下消息转发是怎么一回事。

举一个不恰当的例子：
```objc
id o = [NSObject new];
[o lastObject];
```
执行上面代码，程序会崩溃并抛出以下异常：

```objc
[NSObject lastObject]: unrecognized selector sent to instance 0x100200160
```
错误显而易见，实例对象 `o` 无法响应 `lastObject` 方法。 那么问题来了， Objetive-C 作为一门动态语言，更有强大的 runtime 大佬在背后撑腰，它会让程序没有任何预警地直接狗带么？当然不会，Object-C 的 runtime 不但提供了挽救机制，而且还是三部曲：

1、Lazy method resolution <br>
2、Fast forwarding path <br>
3、Normal forwarding path <br>

上述程序崩溃的根本原因在于没有找到方法的实现，也就是通常所说的 IMP 不存在。结合以下源码，可以知道消息转发三部曲是由 _objc_msgForward 函数发起的。
```c
IMP class_getMethodImplementation(Class cls, SEL sel)
{
    IMP imp;

    if (!cls  ||  !sel) return nil;

    imp = lookUpImpOrNil(cls, sel, nil, 
                         YES/*initialize*/, YES/*cache*/, YES/*resolver*/);

    // Translate forwarding function to C-callable external version
    if (!imp) {
        return _objc_msgForward;
    }

    return imp;
}
```

### Lazy method resolution

在这一步， `_objc_msgForward` 直接或间接调用了以下方法：

```objc
/// 针对类方法
+ (BOOL)resolveClassMethod:(SEL)sel;
/// 针对对象方法
+ (BOOL)resolveInstanceMethod:(SEL)sel;
```
由于形参中传入了无法找到对应 IMP 的 SEL ，我们就可以在这个方法中动态添加 SEL 的实现，并返回 YES 重新启动一次消息发送动作。如果方法返回 NO ，那么就进行消息转发的下个流程 Fast forwarding path 。

这种方式能够方便地实现 `@dynamic` 属性， CoreData 中模型定义中就广泛使用到了 `@dynamic` 属性。

### Fast forwarding path

在这一步， `_objc_msgForward` 直接或间接调用了以下方法：

```objc
- (id)forwardingTargetForSelector:(SEL)aSelector;
```

这个方法还是只附带了无法找到对应 IMP 的 SEL，我们可以根据这个 SEL ，判断是否有其它对象可以响应它，然后选择将消息转发给这个对象。如果返回除 nil / self 之外的对象，那么会重启一次消息发送动作给返回的对象，否则进入下个流程 Normal forwarding path。

### Normal forwarding path

在这一步， `_objc_msgForward` 直接或间接调用了以下方法：

```objc
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;
- (void)forwardInvocation:(NSInvocation *)anInvocation;
```
这个消息转发的最后一步，首先会调用的是 `-methodSignatureForSelector:` 方法，这个方法返回一个方法签名，用以构造 NSInvocation 并作为实参传入 `-forwardInvocation:` 方法中。如果 `-methodSignatureForSelector:` 返回 nil ，将会抛出 unrecognized selector 异常。

由于在 `-forwardInvocation:` 方法中可以获取到 NSInvocation ，而 NSInvocation 包含了参数、发送目标以及 SEL 等信息，尤其是参数信息，所以这一步也是可操作性最强的一步。我们可以选择直接执行传入的 NSInvocation 对象，也可以通过 `-invokeWithTarget:` 指定新的发送目标。

一般来说，既然走到这一步，这个对象都是没有 SEL 对应的 IMP 的，所以通常来说都必须要重写 `-methodSignatureForSelector:` 方法以返回有效的方法签名，否则就会抛出异常。不过有种例外，当对象实现了相应的方法，但还是走到了 Normal forwarding path 这一步时，就可以不重写 `-methodSignatureForSelector:` 方法。

理解这种操作需要知晓 method swizzling 技术中的一个知识点，***替换 IMP 是不会影响到 SEL 和 参数信息的***。所以当把某个方法的实现替换成 `_objc_msgForward` / `_objc_msgForward_stret` 以启动消息转发时，即使不重写 `-methodSignatureForSelector:` ，这个方法依旧能返回有效的方法签名信息。举个例子：

```objc
NSArray *arr = [NSArray new];

Method old = class_getInstanceMethod([arr class], @selector(objectAtIndex:));
printf("old type: %s, imp: %p\n", method_getTypeEncoding(old), method_getImplementation(old));

class_replaceMethod([arr class], @selector(objectAtIndex:), _objc_msgForward, NULL);

Method new = class_getInstanceMethod([arr class], @selector(objectAtIndex:));
printf("new type: %s, imp: %p\n", method_getTypeEncoding(new), method_getImplementation(new));
```

上面程序输出如下：

```objc
old type: @24@0:8Q16, imp: 0x7fffb5fc31e0
new type: @24@0:8Q16, imp: 0x7fffcada5cc0
```
可以看到，更改的只有方法实现 IMP 。并且从源码层面看，method swizzling 在方法已存在的情况下，只是设置了对应的 Method 的 IMP，当方法不存在时，才会设置额外的一些属性：

```objc
IMP 
class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
{
    if (!cls) return nil;

    rwlock_write(&runtimeLock);
    IMP old = addMethod(cls, name, imp, types ?: "", YES);
    rwlock_unlock_write(&runtimeLock);
    return old;
}
static IMP 
addMethod(Class cls, SEL name, IMP imp, const char *types, BOOL replace)
{
    IMP result = nil;

    rwlock_assert_writing(&runtimeLock);

    assert(types);
    assert(cls->isRealized());

    method_t *m;
    // 方法是否存在
    if ((m = getMethodNoSuper_nolock(cls, name))) {
        // already exists
        if (!replace) {
            // 不替换返回已存在方法实现IMP
            result = _method_getImplementation(m);
        } else {
            // 直接替换类cls的m函数指针为imp
            result = _method_setImplementation(cls, m, imp);
        }
    } else {
        // fixme optimize
        // 申请方法列表内存
        method_list_t *newlist;
        newlist = (method_list_t *)_calloc_internal(sizeof(*newlist), 1);
        newlist->entsize_NEVER_USE = (uint32_t)sizeof(method_t) | fixed_up_method_list;
        newlist->count = 1;
        
        // 赋值名字，类型，方法实现（函数指针）
        newlist->first.name = name;
        newlist->first.types = strdup(types);
        if (!ignoreSelector(name)) {
            newlist->first.imp = imp;
        } else {
            newlist->first.imp = (IMP)&_objc_ignored_method;
        }
        
        // 向类添加方法列表
        attachMethodLists(cls, &newlist, 1, NO, NO, YES);

        result = nil;
    }

    return result;
}

```

消息转发流程大体如此，如果想了解具体的转发原理、`_objc_msgForward` 内部是如何实现的，可以阅读[玉令天下](http://yulingtianxia.com/)写的 [Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)，文章会以反汇编地角度剖析消息转发的实现，能捋清不少疑惑。<br>

聊完消息转发的基本流程，再来说说它的一些应用场景。


## Week Proxy

NSTimer、CADisplayLink 是实际项目中常用的计时器类，它们都使用 target - action 机制设置目标对象以及回调方法。相信很多人都遇到过 NSTimer 或者 CADisplayLink 对象造成的循环引用问题。实际上，这两个对象是强引用 target 的，如果使用者管理不当，轻则造成 target 对象的延迟释放，重则导致与 target 对象的循环引用。

假如有个 UIViewController 持有了一个 NSTimer 对象，正确的管理方式是在控制器退出回调中手动 invalidate 并释放对 NSTimer 对象的引用 ：

```
- (void)popViewController {
    [_timer invalidate];
    _timer = nil;
}
```
不过正所谓“人有失手，马有失蹄”，这种分散的管理方式，总会让使用者在某些场景下忘记了将 `_timer` 清空。那么有没有更加优雅的管理机制呢？下面就来看看 FLAnimatedImage 是如何管理 CADisplayLink 对象的。

FLAnimatedImage 创建了以下弱引用代理：
```
@interface FLWeakProxy : NSProxy
+ (instancetype)weakProxyForObject:(id)targetObject;
@end


@interface FLWeakProxy ()
@property (nonatomic, weak) id target;
@end

@implementation FLWeakProxy

#pragma mark Life Cycle

// This is the designated creation method of an `FLWeakProxy` and
// as a subclass of `NSProxy` it doesn't respond to or need `-init`.
+ (instancetype)weakProxyForObject:(id)targetObject
{
    FLWeakProxy *weakProxy = [FLWeakProxy alloc];
    weakProxy.target = targetObject;
    return weakProxy;
}

#pragma mark Forwarding Messages

- (id)forwardingTargetForSelector:(SEL)selector
{
    // Keep it lightweight: access the ivar directly
    return _target;
}


#pragma mark - NSWeakProxy Method Overrides
#pragma mark Handling Unimplemented Methods

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // Fallback for when target is nil. Don't do anything, just return 0/NULL/nil.
    // The method signature we've received to get here is just a dummy to keep `doesNotRecognizeSelector:` from firing.
    // We can't really handle struct return types here because we don't know the length.
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    // We only get here if `forwardingTargetForSelector:` returns nil.
    // In that case, our weak target has been reclaimed. Return a dummy method signature to keep `doesNotRecognizeSelector:` from firing.
    // We'll emulate the Obj-c messaging nil behavior by setting the return value to nil in `forwardInvocation:`, but we'll assume that the return value is `sizeof(void *)`.
    // Other libraries handle this situation by making use of a global method signature cache, but that seems heavier than necessary and has issues as well.
    // See https://www.mikeash.com/pyblog/friday-qa-2010-02-26-futures.html and https://github.com/steipete/PSTDelegateProxy/issues/1 for examples of using a method signature cache.
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}
@end
```
通过上面代码，可以看出 FLWeakProxy 是弱引用 target 的，而且它在消息转发的第二步，将所有的消息都转发给了 target 对象。以下是调用方使用此弱引用代理的代码：

```
@interface FLAnimatedImageView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation FLAnimatedImageView
...
- (void)startAnimating
{
    ...
    FLWeakProxy *weakProxy = [FLWeakProxy weakProxyForObject:self];
    self.displayLink = [CADisplayLink displayLinkWithTarget:weakProxy selector:@selector(displayDidRefresh:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
    ...    
}
...
@end
```
其对象间的引用关系可以用下图表示：

```
---> 强引用  ~~~> 弱引用

FLAnimatedImageView(object) ---> displayLink ---> weakProxy ~~~> FLAnimatedImageView(object)
         
```
这样一来， `displayLink` 间接弱引用了 FLAnimatedImageView 对象，它们之间也就不存在循环引用问题了。而且由于 `weakProxy` 将消息全部转发给了 FLAnimatedImageView 对象，`-displayDidRefresh:` 也得以正确地回调。

此外，苹果私有库 MIME.framework 中就有这种机制的应用 ---- MFWeakProxy ；YYKit 的 YYAnimatedImageView 也使用了相同的机制管理 CADisplayLink，其对应类为 YYWeakProxy 。

## Delegate Proxy

Delegate Proxy 主要实现部分代理方法的转发，顾名思义，就是封装者使用了被封装对象代理的一部分方法，然后将剩余的方法通过新的代理转发给调用者。这种机制在二次封装第三方框架或者原生控件时，能减少不少胶水代码。

接下来，我会以 IGListKit 中的 IGListAdapterProxy 为例，描述如何利用这种机制来简化代码。在开始之前先了解下与 IGListAdapterProxy 直接相关的 IGListAdapter 。 IGListAdapter 是 UICollectionView 的数据源和代理实现者，以下是它与本主题相关联的两个属性：
                                                                                 
```objc
@interface IGListAdapter : NSObject

...

/**
 The object that receives `UICollectionViewDelegate` events.

 @note This object *will not* receive `UIScrollViewDelegate` events. Instead use scrollViewDelegate.
 */
@property (nonatomic, nullable, weak) id <UICollectionViewDelegate> collectionViewDelegate;

/**
 The object that receives `UIScrollViewDelegate` events.
 */
@property (nonatomic, nullable, weak) id <UIScrollViewDelegate> scrollViewDelegate;

...

@end
```
使用者可以成为 IGListAdapter 的代理，获得和 UICollectionView 原生代理一致的编写体验。实际上， IGListAdapter 只是使用并实现了部分代理方法，那么它又是如何编写有关这两个属性的代码，让使用者实现的代理方法能正确地执行呢？可能有些人会这样写：

```
#pragma mark - UICollectionViewDelegateFlowLayout

...

- (BOOL)collectionView:(UICollectionView *)collectionView canFocusItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.collectionViewDelegate respondsToSelector:@selector(collectionView:canFocusItemAtIndexPath:)]) {
        return [self.collectionViewDelegate collectionView:collectionView canFocusItemAtIndexPath:indexPath];
    }
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.collectionViewDelegate respondsToSelector:@selector(collectionView:shouldShowMenuForItemAtIndexPath:)]) {
        [self.collectionViewDelegate collectionView:collectionView shouldShowMenuForItemAtIndexPath:indexPath];
    }
    return YES;
}

...

```
当代理方法较少的时候，这种写法是可以接受的。不过随着代理方法的增多，编写这种胶水代码就有些烦人了，侵入性的修改方式也不符合开放闭合原则。我们来看下 IGListKit 是如何利用 IGListAdapterProxy 解决这个问题的：


```
@interface IGListAdapterProxy : NSProxy
- (instancetype)initWithCollectionViewTarget:(nullable id<UICollectionViewDelegate>)collectionViewTarget
                            scrollViewTarget:(nullable id<UIScrollViewDelegate>)scrollViewTarget
                                 interceptor:(IGListAdapter *)interceptor;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

static BOOL isInterceptedSelector(SEL sel) {
    return (
            // UICollectionViewDelegate
            sel == @selector(collectionView:didSelectItemAtIndexPath:) ||
            sel == @selector(collectionView:willDisplayCell:forItemAtIndexPath:) ||
            sel == @selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:) ||
            // UICollectionViewDelegateFlowLayout
            sel == @selector(collectionView:layout:sizeForItemAtIndexPath:) ||
            sel == @selector(collectionView:layout:insetForSectionAtIndex:) ||
            sel == @selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:) ||
            sel == @selector(collectionView:layout:minimumLineSpacingForSectionAtIndex:) ||
            sel == @selector(collectionView:layout:referenceSizeForFooterInSection:) ||
            sel == @selector(collectionView:layout:referenceSizeForHeaderInSection:) ||
            // UIScrollViewDelegate
            sel == @selector(scrollViewDidScroll:) ||
            sel == @selector(scrollViewWillBeginDragging:) ||
            sel == @selector(scrollViewDidEndDragging:willDecelerate:)
            );
}

@interface IGListAdapterProxy () {
    __weak id _collectionViewTarget;
    __weak id _scrollViewTarget;
    __weak IGListAdapter *_interceptor;
}

@end

@implementation IGListAdapterProxy

- (instancetype)initWithCollectionViewTarget:(nullable id<UICollectionViewDelegate>)collectionViewTarget
                            scrollViewTarget:(nullable id<UIScrollViewDelegate>)scrollViewTarget
                                 interceptor:(IGListAdapter *)interceptor {
    IGParameterAssert(interceptor != nil);
    // -[NSProxy init] is undefined
    if (self) {
        _collectionViewTarget = collectionViewTarget;
        _scrollViewTarget = scrollViewTarget;
        _interceptor = interceptor;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return isInterceptedSelector(aSelector)
    || [_collectionViewTarget respondsToSelector:aSelector]
    || [_scrollViewTarget respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (isInterceptedSelector(aSelector)) {
        return _interceptor;
    }

    return [_scrollViewTarget respondsToSelector:aSelector] ? _scrollViewTarget : _collectionViewTarget;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

@end

```

这个类总共有三个自定义属性，分别是用来支持外界代理方法回调的 `_collectionViewTarget` 、 `_scrollViewTarget`，以及用以支持 AOP 的拦截者 `_interceptor`（IGListAdapter 在调用外界实现的代理方法前，插入了自己的实现，所以可视为拦截者）。 `isInterceptedSelector` 函数表明拦截者使用到了哪些代理方法，而 `-respondsToSelector:` 和 `-forwardingTargetForSelector:` 则根据这个函数的返回值决定是否能响应方法，以及应该把消息转发给拦截者还是外部代理。 事实上，外部代理就是本小节开头所说的使用者可以访问的属性：

```
@implementation IGListAdapter
...
self.delegateProxy = [[IGListAdapterProxy alloc] initWithCollectionViewTarget:_collectionViewDelegate
                                                                 scrollViewTarget:_scrollViewDelegate
                                                                      interceptor:self];
...
@end
```

通过这种转发机制，即使后续有新的代理方法，也不用手动添加胶水代码了。一些流行的开源库中也可以看到这种做法的身影，比如 AsyncDisplayKit 就有对应的 `_ASCollectionViewProxy` 来转发未实现的代理方法。


## Multicast Delegate

通知和代理是解耦对象间消息传递的两种重要方式，其中通知主要针对一对多的单向通信，而代理则主要提供一对一的双向通信。

通常来说， IM 应用在底层模块接受到新消息后，都会进行一次广播处理，让各模块能根据新消息来更新状态。当接收模块不需要向发送模块反馈任何信息时，使用 NSNotificationCenter 就可以实现上述需求。但是一旦发送模块需要根据接收模块返回的信息做一些额外处理，也就是实现一对多的双向通信， NSNotificationCenter 就不满足要求了。

最直接的解决方案是，针对这个业务场景自定义一个消息转发中心，让遵守特定协议的外围模块主动注册成为消息接收者。不过既然涉及到了特定协议，就注定了这个消息转发中心缺少通用性。这时候就可以参考下业界现成的方案了，让我们来看看 XMPPFramework 是如何解决这个问题的。

从文档中可以看出，作者希望 XMPPFramework 具备以下几个特性 ：

1、 将事件广播给多个监听者<br>
2、 易于扩展<br>
3、 选择的机制要支持返回值<br>
4、 选择的机制要易于编写线程安全代码<br>

但是代理或者通知机制都不能很好地满足上述需求，所以 GCDMulticastDelegate 类应运而生。 使用这个类时，广播类需要初始化 GCDMulticastDelegate 对象：

```

GCDMulticastDelegate <MyPluginDelegate> *multicastDelegate;
multicastDelegate = (GCDMulticastDelegate <MyPluginDelegate> *)[[GCDMulticastDelegate alloc] init];
```
并且添加增删代理的方法：

```
- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    [multicastDelegate addDelegate:delegate delegateQueue:delegateQueue];
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    [multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
}
```
当广播对象需要向所有注册的代理发送消息时，可以用以下方式调用：

```
[multicastDelegate worker:self didFinishSubTask:subtask inDuration:elapsed];
```
只要注册的代理实现了这个方法，就可以接收到发送的信息。

接下来看下 GCDMulticastDelegate 的实现原理 。首先， GCDMulticastDelegate 会在外界添加代理时，创建 GCDMulticastDelegateNode 对象封装传入的代理以及回调执行队列，然后保存在 `delegateNodes` 数组中。当外界向 GCDMulticastDelegate 对象发送无法响应的消息时，它会针对此消息启动转发机制，并在 `Normal forwarding path` 这一步转发给所有能响应此消息的注册代理。以下是消息转发相关的源码：

```
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    for (GCDMulticastDelegateNode *node in delegateNodes)
    {
        id nodeDelegate = node.delegate;
        #if __has_feature(objc_arc_weak) && !TARGET_OS_IPHONE
        if (nodeDelegate == [NSNull null])
            nodeDelegate = node.unsafeDelegate;
        #endif
        
        NSMethodSignature *result = [nodeDelegate methodSignatureForSelector:aSelector];
        
        if (result != nil)
        {
            return result;
        }
    }
    
    // This causes a crash...
    // return [super methodSignatureForSelector:aSelector];
    
    // This also causes a crash...
    // return nil;
    
    return [[self class] instanceMethodSignatureForSelector:@selector(doNothing)];
}

- (void)forwardInvocation:(NSInvocation *)origInvocation
{
    SEL selector = [origInvocation selector];
    BOOL foundNilDelegate = NO;
    
    for (GCDMulticastDelegateNode *node in delegateNodes)
    {
        id nodeDelegate = node.delegate;
        #if __has_feature(objc_arc_weak) && !TARGET_OS_IPHONE
        if (nodeDelegate == [NSNull null])
            nodeDelegate = node.unsafeDelegate;
        #endif
        
        if ([nodeDelegate respondsToSelector:selector])
        {
            // All delegates MUST be invoked ASYNCHRONOUSLY.
            
            NSInvocation *dupInvocation = [self duplicateInvocation:origInvocation];
            
            dispatch_async(node.delegateQueue, ^{ @autoreleasepool {
                
                [dupInvocation invokeWithTarget:nodeDelegate];
                
            }});
        }
        else if (nodeDelegate == nil)
        {
            foundNilDelegate = YES;
        }
    }
    
    if (foundNilDelegate)
    {
        // At lease one weak delegate reference disappeared.
        // Remove nil delegate nodes from the list.
        // 
        // This is expected to happen very infrequently.
        // This is why we handle it separately (as it requires allocating an indexSet).
        
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
        
        NSUInteger i = 0;
        for (GCDMulticastDelegateNode *node in delegateNodes)
        {
            id nodeDelegate = node.delegate;
            #if __has_feature(objc_arc_weak) && !TARGET_OS_IPHONE
            if (nodeDelegate == [NSNull null])
                nodeDelegate = node.unsafeDelegate;
            #endif
            
            if (nodeDelegate == nil)
            {
                [indexSet addIndex:i];
            }
            i++;
        }
        
        [delegateNodes removeObjectsAtIndexes:indexSet];
    }
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    // Prevent NSInvalidArgumentException
}

- (void)doNothing {}
```

可以看到， `-methodSignatureForSelector:` 方法遍历了 `delegateNodes` ，并返回首个有效的方法签名。当没有找到有效的方法签名时，会返回 `-doNothing` 方法的签名，以规避未知方法导致的崩溃。在得到方法签名并构造 NSInvocation 对象后， `-forwardInvocation:` 同样遍历了 `delegateNodes` ，并在特定的任务队列中执行代理回调。如果发现已被销毁的代理，则删除它对应的 GCDMulticastDelegateNode 对象。

## Record Message Call

NSUndoManager 是 Foundation 框架中，一个基于命令模式设计的撤消栈管理类。通过这个类可以很方便地实现撤消、重做功能，比如以下苹果官方 Demo ：


```objc
- (void)setMyObjectWidth:(CGFloat)newWidth height:(CGFloat)newHeight{
 
    float currentWidth = [myObject size].width;
    float currentHeight = [myObject size].height;
    if ((newWidth != currentWidth) || (newHeight != currentHeight)) {
        [[undoManager prepareWithInvocationTarget:self]
                setMyObjectWidth:currentWidth height:currentHeight];
        [undoManager setActionName:NSLocalizedString(@"Size Change", @"size undo")];
        [myObject setSize:NSMakeSize(newWidth, newHeight)];
    }
}
```
通过调用代码块中 NSUndoManager 对象的 `undo` ， 可以“撤销”以上方法对 myObject 相关属性的设置。其中需要关注的是， NSUndoManager 是如何记录目标对象接收发生改变的信息：

```objc
[[undoManager prepareWithInvocationTarget:self] setMyObjectWidth:currentWidth height:currentHeight]
```

NSUndoManager 是如何通过这种方式存储调用 `-setMyObjectWidth:height:` 这一动作呢？背后的关键在于 `-prepareWithInvocationTarget:`
所返回的对象，也就是 NSUndoManagerProxy 。 NSUndoManagerProxy 是 NSProxy 的子类，而 NSProxy 除了重载消息转发机制外，基本上就没有其他用法了。结合苹果官方文档， NSUndoManagerProxy 重载了 `-forwardInvocation:` 来帮助 NSUndoManager 获取目标的方法调用信息。到目前为止，这个应用场景并不难理解，不过为了能切合 NSUndoManagerProxy 的实际实现，这里还是结合 Foundation 框架反汇编出的代码，简单地实现这个功能。

首先，创建 TBVUndoProxy ， 重写它的消息转发机制：

```objc
@interface TBVUndoProxy : NSProxy
@property (weak, nonatomic) TBVUndoManager *manager;
@end


@implementation TBVUndoProxy
- (void)forwardInvocation:(NSInvocation *)invocation {
    [_manager _forwardTargetInvocation:invocation];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_manager _methodSignatureForTargetSelector:sel];
}
@end
```
结合 LLDB 中的调试信息， TBVUndoProxy 只是简单地把信息传送给了 TBVUndoManager 。再来看下将原生逻辑简化后的 TBVUndoManager 的实现：

```objc
@interface TBVUndoManager : NSObject {
    NSMutableArray *_invocations;
    TBVUndoProxy *_proxy;
    __weak id _target;
}

- (id)prepareWithInvocationTarget:(id)target;

- (void)undo;
@end

@interface TBVUndoManager (Private)
- (void)_forwardTargetInvocation:(NSInvocation *)invocation;
- (NSMethodSignature *)_methodSignatureForTargetSelector:(SEL)sel;
@end

@implementation TBVUndoManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        _invocations = [NSMutableArray array];
    }
    return self;
}

- (id)prepareWithInvocationTarget:(id)target {
    _target = target;
    _proxy = [TBVUndoProxy alloc];
    _proxy.manager = self;
    
    return _proxy;
}

- (void)undo {
    [_invocations.lastObject invoke];
    [_invocations removeObject:_invocations.lastObject];
}

- (void)_forwardTargetInvocation:(NSInvocation *)invocation {
    [invocation setTarget:_target];
    [_invocations addObject:invocation];
}

- (NSMethodSignature *)_methodSignatureForTargetSelector:(SEL)sel {
   NSMethodSignature *signature = [super methodSignatureForSelector:sel];
    if (!signature && _target) {
        signature = [_target methodSignatureForSelector:sel];
    }
    return signature;
}
@end
```
TBVUndoManager 通过 `-prepareWithInvocationTarget:` 方法将发送消息对象保存为 `_target` 成员变量，然后创建了代理类 TBVUndoProxy 并返回给方法调用者。当外部调用者用这个返回值作为消息发送对象时， TBVUndoProxy 并没有对应的方法实现，于是就触发了消息转发机制， TBVUndoManager 则利用保存的 `_target` 返回有效的方法签名，并且保存重组了  TBVUndoProxy 回传的 NSInvocation。最终，当外界调用 `undo` 时，执行的就是保有 `_target` 和 `-prepareWithInvocationTarget:`  信息的 NSInvocation 。（原生代码将 NSInvocation 包装成 `_NSUndoInvocation` 、 `_NSUndoObject` 压入 `_NSUndoStack` 栈中）


## Intercept Any Message Call

Aspects 是一个提供面向切片编程的库，它可以让开发者以无侵入的方式添加额外的功能。它提供了两个简单易用的入口，用于 hook 特定类或者特定对象的方法：

```
/// Adds a block of code before/instead/after the current `selector` for a specific class.
+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

/// Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;
```

开发者可以用以下方式 hook 所有 UIViewController 实例对象的 `-viewWillAppear:` 方法 :

```
[UIViewController aspect_hookSelector:@selector(viewWillAppear:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
    NSLog(@"View Controller %@ will appear animated: %tu", aspectInfo.instance, animated);
} error:NULL];
```

因为不知道使用者会 hook 什么方法，所以就无法像传统的 swizzling method 一样，预先编写对应的 IMP 去替换传入的方法。这时就需要内部实现一个统一调用机制，这个机制需要满足以下两点：

1、 为了能进行切片操作，需要让所有被 hook 方法的调用都通过一个统一的入口完成。<br>
2、 为了给原始实现和切片操作提供参数/返回值信息，这个入口要能获取被 hook 方法完整的签名信息。<br>


综合上述两点以及 Normal forwarding path 的执行过程，可以比较轻松地联想到 `-forwardInvocation:` 方法非常适合作为这个入口。结合 Aspects 源码，来看下其实现中，和消息转发相关的两个步骤：

```
static void aspect_prepareClassAndHookSelector(NSObject *self, SEL selector, NSError **error) {
    NSCParameterAssert(selector);
    Class klass = aspect_hookClass(self, error);
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!aspect_isMsgForwardIMP(targetMethodIMP)) {
        // Make a method alias for the existing method implementation, it not already copied.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        if (![klass instancesRespondToSelector:aliasSelector]) {
            __unused BOOL addedAlias = class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        }

        // We use forwardInvocation to hook in.
        class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);
        AspectLog(@"Aspects: Installed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }
}

static Class aspect_hookClass(NSObject *self, NSError **error) {
    NSCParameterAssert(self);
   ...
        aspect_swizzleForwardInvocation(subclass);
   ...
}
static void aspect_swizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    // If there is no method, replace will act like class_addMethod.
    IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
    }
    AspectLog(@"Aspects: %@ is now aspect aware.", NSStringFromClass(klass));
}
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    ...

    // Before hooks.
    aspect_invoke(classContainer.beforeAspects, info);
    aspect_invoke(objectContainer.beforeAspects, info);

    // Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadAspects.count || classContainer.insteadAspects.count) {
        aspect_invoke(classContainer.insteadAspects, info);
        aspect_invoke(objectContainer.insteadAspects, info);
    }else {
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }

    // After hooks.
    aspect_invoke(classContainer.afterAspects, info);
    aspect_invoke(objectContainer.afterAspects, info);

    ...
}
```

这里在忽略掉 Aspects 创建子类等操作后，可以看出以上代码总共做了两件事：

1、对原始 `-forwardInvocation:` 方法执行 swizzling method ，将实现替换成 `__ASPECTS_ARE_BEING_CALLED__` ，以便在 `__ASPECTS_ARE_BEING_CALLED__` 函数中执行了额外的切片操作。<br>
2、对被 hook 的方法执行 swizzling method ，将实现替换成 `_objc_msgForward` / `_objc_msgForward_stret` ，以便触发被 hook 方法的消息转发机制，然后在步骤 1 的 `__ASPECTS_ARE_BEING_CALLED__` 函数中，进行切片操作。<br>


值得一提的是， JSPatch 也是利用相似的机制，实现用 `defineClass` 接口任意替换一个类的方法的功能，不同的是 JSPatch 在它的 `__ASPECTS_ARE_BEING_CALLED__` 函数中，直接把参数传给了 JavaScript 的实现。

<!-- ## Dependency Injection -->

<!-- ## 依靠协议的依赖注入 -->


## 小结
消息转发有三步，分别是 Lazy method resolution （动态添加方法）、 Fast forwarding path （转发至可响应对象）、 Normal forwarding path （获取 NSInvocation 信息）。关于消息转发的应用，本文主要摘录了以下几个例子：

- Week Proxy
- Delegate Proxy
- Multicast Delegate
- Record Message Call
- Intercept Any Message Call

可以看出，在这些例子中，都创建了一个代理类，并且这个代理类几乎没有实现自定义方法，或者直接是 NSProxy 的子类。这样，基本上所有的发送给代理类对象的消息，都会触发消息转发机制，而这个代理类就可以对拦截的消息做额外处理。

其中大部分应用场景都涉及到消息转发的第二三步，即 Fast forwarding path、Normal forwarding path 。特别是 Normal forwarding path ，配合 `_objc_msgForward` / `_objc_msgForward_stret` 函数强行进行消息转发，可以获取携带完整调用信息的 NSInvocation 。借助于 NSInvocation 的灵活性，开发者就可以完成一些非常有意思的事情了。


## 参考

[MulticastDelegate](https://github.com/robbiehanson/XMPPFramework/wiki/MulticastDelegate)<br>
[Smart Proxy Delegation](http://petersteinberger.com/blog/2013/smart-proxy-delegation/)<br>
[Objective-C Message Forwarding](https://mikeash.com/pyblog/friday-qa-2009-03-27-objective-c-message-forwarding.html)<br>
[Objective-C 中的消息与消息转发](http://blog.ibireme.com/2013/11/26/objective-c-messaging/) <br>
[Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)<br>
[AOP. Delivered](https://codeshaker.blogspot.jp/2012/01/aop-delivered.html) <br>
[面向切面编程之 Aspects 源码解析及应用](https://wereadteam.github.io/2016/06/30/Aspects/)<br>
[JSPatch 实现原理详解](https://github.com/bang590/JSPatch/wiki/JSPatch-%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3)<br>

