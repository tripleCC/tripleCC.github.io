---
layout: post
title: "RunLoop基础元素解析"
date: 2015-09-04 21:58:21 +0800
comments: true
categories: 
tags: [runloop]
---

[深入理解RunLoop](http://blog.ibireme.com)这篇文章写的很好！

## 简介

RunLoop顾名思义，就是`运行循环`的意思。<br>
基本作用：

- 保持程序的持续运行
- 处理App中的各类事件（触摸事件、定时器事件、Selector事件）
- 节省CPU资源，提高程序性能：没有事件时就进行睡眠状态

内部实现：

- do-while循环，在这个循环内部不断地处理各种任务（Source\Timeer\Observer）
<!--more-->
注意点：

- 一个线程对应一个RunLoop（采用字典存储，`线程号为key，RunLoop为value`）
- 主线程的RunLoop默认已经启动，子线程的RunLoop需要手动启动
- RunLoop只能选择一个Mode启动，如果当前Mode没有任何Source、Timer、Observer，那么就不会进入RunLoop
  - RunLoop的主要函数调用顺序为：`CFRunLoopRun->CFRunLoopRunSpecific->__CFRunLoopRun`
  ![](/images/Snip20150713_2.png)<br>
  - `注意特殊情况`，事实上，在`只有`Observer的情况，也不一定会进入循环，因为源代码里面只会显式地检测两个东西：`Source和Timer`(这两个是主动向RunLoop发送消息的)；Observer是被动接收消息的<br>
    ![](/images/Snip20150713_11.png)

- RunLoop在`第一次获取时创建`，在`线程结束时销毁`

RunLoop循环示意图:(针对上面的`__CFRunLoopRun`函数，Mode已经判断非空前提)

 - 图1<br>![RunLoop循环示意图](/images/Snip20150712_39.png)<br>
 - 图2<br>![](/images/Snip20150713_3.png)<br>

接触过微处理器编程的基本上都知道，在编写微处理器程序时，我通常会在main函数中写一个无限循环，然后在这个循环里面对外部事件进行监听，比如外部中断，一些传感器的数据等，在没有外部中断时，就让CPU进入低功耗模式。如果接收到了外部中断，就恢复到正常模式，对中断进行处理。

```objc
while (1) {
  // 根据中断决定是否切换模式执行任务
}
// 或者
for (;;) {
}
```
RunLoop和这个相似，也是在线程的main中增加了一个循环：

```objc
int main(int argc, char * argv[]) {
    BOOL running = YES;
    do {
        // 执行各种任务，处理各种事件
             // ......
    } while (running);
    return 0;
}
```
所以线程在这种情况下，便不会退出。<br>
关于`MainRunLoop`：

```objc
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```
在viewDidLoad中设置断电，然后得到以下主线程栈信息：<br>
![](/images/Snip20150712_40.png)<br>
可以看到，UIApplicationMain内部启动了一个和主线程相关联的RunLoop（_CFRunLoopRun）。在这里也可以推断，程序进入UIApplicationMain就不会退出了。我稍微对主函数进行了如下修改，并在return语句上打印了断点：<br>
![](/images/Snip20150712_41.png)<br>
运行程序后，并不会在断点处停下，证实了上面的推断。

上面涉及了一个_CFRunLoopRun函数，接下来说明下iOS中访问和使用RunLoop的API：

- Foundation--NSRunLoop
- Core Foundation--CFRunLoopRef(开源)

因为后者是开源的，且前者是在后者上针对OC的封装，所以一般是对CFRunLoopRef进行研究。<br>
两套API对应获取RunLoop对象的方式：

- Foundation
  - [NSRunLoop currentRunLoop]; // 当前runloop
  - [NSRunLoop mainRunLoop];// 主线程runloop
- Core Foundation
  - CFRunLoopGetCurrent();// 当前runloop
  - CFRunLoopGetMain();// 主线程runloop

值得注意的是，获取当前RunLoop都是进行懒加载的，也就是调用时自动创建线程对应的RunLoop。<br>

### RunLoop相关类：

- CFRunLoopRef
- CFRunLoopModeRef
- CFRunLoopSourceRef
- CFRunLoopTimerRef
- CFRunLoopObserverRef

![类之间关系](/images/Snip20150712_43.png)<br>
以上图片说明了各个类之间的关系。<br>
`CFRunLoopModeRef`说明：

  - 代表RunLoop的运行模式，一个RunLoop可以包含多个Mode，每个Mode可以包含多个Source、Timer、Observer
  - 每次RunLoop启动时，只能指定其中一个Mode，这个Mode就变成了CurrentMode
  - 当启动RunLoop时，如果所在Mode中没有Source、Timer、Observer，那么将不会进入RunLoop，会直接结束
  - 如果要切换Mode，只能退出Loop，再重新制定一个Mode进入

系统默认注册了5个Mode:

- `NSDefaultRunLoopMode`：App的默认Mode，通常主线程是在这个Mode下运行
- `UITrackingRunLoopMode`：界面跟踪 Mode，用于 ScrollView 追踪触摸滑动，保证界面滑动时不受其他 Mode 影响
- UIInitializationRunLoopMode: 在刚启动 App 时第进入的第一个 Mode，启动完成后就不再使用
- GSEventReceiveRunLoopMode: 接受系统事件的内部 Mode，通常用不到
- `NSRunLoopCommonModes`: 这是一个占位用的Mode，不是一种真正的Mode

关于`NSRunLoopCommonModes`：

 - 一个Mode可以将自己标记为“Common”属性，每当 RunLoop 的内容发生变化时，RunLoop会对标记有“Common”属性的Mode进行相适应的切换，并同步Source/Observer/Timer
 - 在主线程中，kCFRunLoopDefaultMode 和 UITrackingRunLoopMode这两个Mode都是被默认标记为“Common”属性的，从输出的主线程RunLoop可以查看。<br>![“Common”属性](/images/Snip20150712_42.png)<br>
 － 结合上面两点，当使用NSRunLoopCommonModes占位时，会表明使用标记为“Common”属性的Mode，在一定层度上，可以说是“拥有了两个Mode”，可以在这两个Mode中的其中任意一个进行工作

`CFRunLoopTimerRef`说明：

 - CFRunLoopTimerRef是基于时间的触发器，它包含了一个时间长度和一个回调函数指针。当它加入到RunLoop时，RunLoop会注册对应的时间点，当时间点到时，RunLoop会被唤醒以执行那个回调
 - CFRunLoopTimerRef大部分指的是NSTimer，它受RunLoop的Mode影响
 - 由于NSTimer在RunLoop中处理，所以受其影响较大，有时可能会不准确。还有一种定时器是GCD定时器，它并不在RunLoop中，所以不受其影响，也就比较精确
接下来说明各种Mode下，NSTimer的工作情况：

- 情况1
  - 在对创建的定时器进行模式修改前，scheduledTimerWithTimeInterval创建的定时器只在NSDefaultRunLoopMode模式下可以正常运行，当滚动UIScroolView时，模式转换成UITrackingRunLoopMode，定时器就失效了。
  - 修改成NSRunLoopCommonModes后，定时器在两个模式下都可以正常运行

```objc
// 创建的定时器默认添加到当前的RunLoop中（没有就创建），而且是NSDefaultRunLoopMode模式
NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(run) userInfo:nil repeats:YES];

// 可以通过以下方法对模型进行修改
[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```
- 情况2
  - timerWithTimeInterval创建的定时器并没有手动添加进RunLoop，所以需要手动进行添加。当添加为以下模式时，定时器只在UITrackingRunLoopMode模式下进行工作，也就是滑动UIScrollView时就会工作，停止滑动时就不工作
  - 如果把UITrackingRunLoopMode换成NSDefaultRunLoopMode，那么效果就和情况1没修改Mode前的效果一样

```objc
NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(run) userInfo:nil repeats:YES];

// 在UITrackingRunLoopMode模式下定时器才会运行
[[NSRunLoop mainRunLoop] addTimer:timer forMode:UITrackingRunLoopMode];
```

`CFRunLoopSourceRef`说明：

- Source分类
  - 按官方文档
    - Port-Based Sources
	- Custom Input Sources
	- Cocoa Perform Selector Sources
  - 按照函数调用栈
    - Source0：非基于Port的
      - Source0本身不能主动触发事件，只包含了一个回调函数指针
	- Source1：基于Port的，通过内核和其他线程通信，接收、分发系统事件
	  - 包含了mach_port和一个回调函数指针，接收到相关消息后，会分发给Source0进行处理

`CFRunLoopObserverRef`说明：
- CFRunLoopObserverRef是观察者，能够监听RunLoop的状态改变
- 能够监听的状态

```objc
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
        kCFRunLoopEntry = (1UL << 0),        // 进入RunLoop
        kCFRunLoopBeforeTimers = (1UL << 1), //即将处理timer
        kCFRunLoopBeforeSources = (1UL << 2),//即将处理Sources
        kCFRunLoopBeforeWaiting = (1UL << 5),//即将进入休眠
        kCFRunLoopAfterWaiting = (1UL << 6), //即将唤醒
        kCFRunLoopExit = (1UL << 7),         //即将退出RunLoop
        kCFRunLoopAllActivities = 0x0FFFFFFFU//所有活动
    };
```
- 添加监听者步骤

```objc
	// 创建监听着
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopBeforeTimers, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"%ld", activity);
    });

    //    [[NSRunLoop currentRunLoop] getCFRunLoop]
    // 向当前runloop添加监听者
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);

    // 释放内存
    CFRelease(observer);
```

CF的内存管理（Core Foundation）：

- 1.凡是带有Create、Copy、Retain等字眼的函数，创建出来的对象，都需要在最后做一次release
 * 比如CFRunLoopObserverCreate
- 2.release函数：CFRelease(对象);

### 自动释放池释放的时间和RunLoop的关系：

  - 注意，这里的自动释放池指的是`主线程的自动释放池`，我们看不见它的创建和销毁。自己`手动创建@autoreleasepool {}`是`根据代码块来的`，`出了这个代码块就释放了`。
  -  App启动后，苹果在主线程 RunLoop 里注册了两个 Observer，其回调都是 `_wrapRunLoopWithAutoreleasePoolHandler()`。
  - 第一个 Observer 监视的事件是 Entry(`即将进入Loop`)，其回调内会调用 _objc_autoreleasePoolPush() `创建自动释放池`。其 order 是-2147483647，优先级最高，保证创建释放池发生在其他所有回调之前。
  <br>![](/images/Snip20150713_5.png)
  - 第二个 Observer 监视了两个事件： BeforeWaiting(`准备进入休眠`) 时调用_objc_autoreleasePoolPop() 和 _objc_autoreleasePoolPush() `释放旧的池并创建新池`；Exit(`即将退出Loop`) 时调用 _objc_autoreleasePoolPop() 来`释放自动释放池`。这个 Observer 的 order 是 2147483647，优先级最低，保证其释放池子发生在其他所有回调之后。
  <br>![](/images/Snip20150713_4.png)
  - 在主线程执行的代码，通常是写在诸如事件回调、Timer回调内的。这些回调会被 RunLoop 创建好的 AutoreleasePool 环绕着，所以不会出现内存泄漏，开发者也不必显示创建 Pool 了。
  - 在`自己创建线程`时，需要`手动创建`自动释放池`AutoreleasePool`

综合上面，可以得到以下结论：<br>
![](/images/Snip20150713_12.png)

### @autoreleasepool {}内部实现

有以下代码：

```objc
int main(int argc, const char * argv[]) {
    @autoreleasepool {
    }

    return 0;
}
```
查看编译转换后的代码：

```objc
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
    }

    return 0;
}
```
__AtAutoreleasePool是什么呢？找到其定义：

```objc
struct __AtAutoreleasePool {
  __AtAutoreleasePool() {atautoreleasepoolobj = objc_autoreleasePoolPush();}
  ~__AtAutoreleasePool() {objc_autoreleasePoolPop(atautoreleasepoolobj);}
  void * atautoreleasepoolobj;
};
```
可以看到__AtAutoreleasePool是一个类：
  - 其构造函数使用objc_autoreleasePoolPush创建了一个线程池，并保存给成员变量atautoreleasepoolobj。
  - 其析构函数使用objc_autoreleasePoolPop销毁了线程池

结合以上信息，main函数里面的__autoreleasepool是一个局部变量。当其创建时，会调用构造函数创建线程池，出了{}代码块时，局部变量被销毁，调用其析构函数销毁线程池。

## RunLoop实际应用
### 常驻线程

当创建一个线程，并且希望它一直存在时，就需要使用到RunLoop，否则线程一执行完任务就会停止。
要向线程存在，需要有强指针引用他，其他的代码如下：

```objc
// 属性
@property (strong, nonatomic) NSThread *thread;

// 创建线程
_thread = [[NSThread alloc] initWithTarget:self selector:@selector(test) object:nil];
[_thread start];

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // 点击时使线程_thread执行test方法
    [self performSelector:@selector(test) onThread:_thread withObject:nil waitUntilDone:NO];
}

//
- (void)test
{
    NSLog(@"__test__");
}
```
就单单以上代码，是不起效果的，因为线程没有RunLoop，执行完test后就停止了，无法再让其执行任务（强制start会崩溃）。<br>
通过在`子线程中给RunLoop添加监听者`，可以了解下`performSelector:onThread: `内部做的事情：

  - 调用performSelector:onThread: 时，实际上它会创建一个`Source0`加到`对应线程的RunLoop`里去，所以，如果对应的线程没有RunLoop，这个方法就会失效<br>
  ![](/images/Snip20150716_5.png)

```objc
    // 这句在主线程中调用
    // _thread就是下面的线程

    [self performSelector:@selector(run) onThread:_thread withObject:nil waitUntilDone:NO];

```
  - performSelecter:afterDelay:也是一样的内部操作方法，只是创建的`Timer`添加到`当前线程`的RunLoop中了<br>
  ![](/images/Snip20150716_6.png)

```objc
    // 创建RunLoop即将唤醒监听者
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopBeforeTimers, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {

        // 打印唤醒前的RunLoop
        NSLog(@"%ld--%@", activity, [NSRunLoop currentRunLoop]);
    });

    // 向当前runloop添加监听者
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);

    // 释放内存
    CFRelease(observer);

    [self performSelector:@selector(setView:) withObject:nil afterDelay:2.0];

      // 使model不为空
    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];

```

综合上面的解释，可以知道performSelector:onThread:没有起作用，是因为_thread线程内部没有RunLoop，所以需要在线程内部创建RunLoop。<br>
创建RunLoop并使对应线程成为常驻线程的常见方式有2:

- 方式1
  - 向创建的RunLoop添加NSPort（Sources），让Mode不为空，RunLoop能进入循环不会退出

  	```objc
  	[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
  	[[NSRunLoop currentRunLoop] run];
  	```
- 方式2
  - 让RunLoop一直尝试运行，判断Mode是否为空，不是为空就进入RunLoop循环

    ```objc
    while (1) {
        [[NSRunLoop currentRunLoop] run];
    }

    ```

`AFNetWorking`就使用到了常驻线程：

  - 创建常驻线程

```objc
+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"AFNetworking"];

        // 创建RunLoop并向Mode添加NSMachPort，使RunLoop不会退出
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });

    return _networkRequestThread;
}
```
  - 使用常驻线程

```objc
- (void)start {
    [self.lock lock];
    if ([self isCancelled]) {
        [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    } else if ([self isReady]) {
        self.state = AFOperationExecutingState;

        [self performSelector:@selector(operationDidStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    }
    [self.lock unlock];
}
```

### 给子线程开启定时器

```objc
_thread = [[NSThread alloc] initWithTarget:self selector:@selector(test) object:nil];
[_thread start];


// 子线程添加定时器
- (void)subTimer
{
    // 默认创建RunLoop并向其model添加timer，所以后续只需要让RunLoop run起来即可
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(run) userInfo:nil repeats:YES];

    // 貌似source1不为空，source0就不为空
//    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
}
```

### 让某些事件（行为、任务）在特定模式下执行

比如图片的设置，在UIScrollView滚动的情况下，我不希望设置图片，等停止滚动了再设置图片，可以用以下代码：

```objc
// 图片只在NSDefaultRunLoopMode模式下会进行设置显示
    [self.imageView performSelector:@selector(setImage:) withObject:[UIImage imageNamed:@"Snip20150712_39"] afterDelay:2.0 inModes:@[NSDefaultRunLoopMode]];
```
先设置任务在NSDefaultRunLoopMode模式在执行，这样，在滚动使RunLoop进入UITrackingRunLoopMode时，就不会进行图片的设置了。


### 控制定时器在特定模式下执行

上文的《`CFRunLoopTimerRef`说明：》中已经指出

### 添加Observer监听RunLoop的状态

监听点击事件的处理（在所有点击事件之前做一些事情）<br>
具体步骤在《`CFRunLoopObserverRef`说明：》中已写明


#GCD定时器
注意：

- dispatch_source_t是个类，这点比较特殊

```objc
//    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);

    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"__");

        NSLog(@"%@", [NSThread currentThread]);

        static NSInteger count = 0;

        if (count++ == 3) {
            // 为什么dispatch_cancel不能用_timer?/
            // Controlling expression type '__strong dispatch_source_t' (aka 'NSObject<OS_dispatch_source> *__strong') not compatible with any generic association type
            // 类型错误，可能dispatch_cancel是宏定义，需要的就是方法调用，而不是变量
//            dispatch_cancel(self.timer);

            dispatch_source_cancel(_timer);
        }
    });
    // 定时器默认是停止的，需要手动恢复
    dispatch_resume(timer);

    // 需要一个强引用保证timer不被释放
    _timer = timer;
```

最后一点需要说明的是，SDWebImage框架的下载图片业务中也使用到了RunLoop，老确保图片下载成功后才关闭任务子线程