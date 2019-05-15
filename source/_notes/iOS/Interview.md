### 你在项目中用过 runtime 吗？举个例子

**项目中用的**

- AppDelegate 初始化方法拆分

  - 替换 setDelegate 方法，并且在消息转发的 forward invocation 阶段向注册的模块转发代理消息
  - 通过上述方法实现组件接入即可用，即使使用改组件的壳工程没有实现对应的代理方法，组件也可以接收到代理消息

- Week Proxy

  - 弱引用实际对象，在 forward target 阶段，把消息转发给这个对象
  - 比如 NSTimer / CADisplayLink 会持有 target ，用 week proxy 包装一层避免循环引用

- Delegate Proxy

  - 弱引用实际对象，在 forward target 阶段，把部分不使用的代理消息转发给这个对象
  - 比如我们的表单组件用了 tableView 的部分代理方法，就可以用 Delegate Proxy 把不使用的 tableViewDelegate 和 scrollViewDelegate 的代理方法转发出去，不用写胶水代码 

**系统/三方中用的**

- NSUndoManager 命令模式设计的撤销栈管理类

  - 在 forward invocation 阶段去记录调用撤销方法的全部信息，执行 undo 时再调用这个方法

- KVO
  - 添加监听者时，动态创建监听对象类的子类，并且替换监听对象的 isa 为新创建的子类，然后重写 setter 方法，在 setter 方法里面去通知监听者属性变更
- Aspects
  - Aspects 实现 AOP 也基于 runtime ，它会去替换目标方法实现为消息转发入口函数 (_objc_msgForward) ，然后在自定义的 forward invocation (替换过的) 中执行切片操作。还有 Aspects 对于 hook 单个对象的  部分实现和 KVO 差不多，都是动态创建子类。

###  你在项目中用过 GCD 吗？举个例子

- 处理多个网络请求
  - 封装 APIKit 时，业务层有多个网络请求完成后再处理业务的需求，使用了 group ，在请求时调用 enter ，完成时调用 leave ，最终在 notify 上执行回调

- 解压 json 配置包
  - 我们内部有个通过 json 配置页面的框架，这些 json 预置在 zip 包里，app launch 的时候会去解压缩，这里的解压缩操作是 async 到全局队列里面去做的

###  Category 的实现原理，以及 Category 为什么只能加方法/属性，不能添加成员变量

- category 是什么？
  - category 实际上是方法、属性、协议的集合体，保存在 category_t 结构体中
- class 怎么合并 category？
  - 合并分两个时间点。category 和 class 一样，编译之后会以全局变量的形式保存在 DATA 段中，在 objc init 阶段，runtime 会在处理 image 的回调函数 read_image 中，去 DATA 段读取所有的 category ，如果对应的 class 已经 realized ，会直接将 category 的 方法、属性、协议插入到 class 结构中对应字段起始位置；如果 class 还没 realized ，那么等 class 被 realized 时，再去合并。
  - 这里可以看出一个点，由于 category 的方法在 class 原生的方法前，查找方法时，会优先获取 category 的方法
  - realized 在对类进行初始化时设置，initialized 在首次向类发送消息执行 +initialize 方法时设置
- 不能添加成员变量？
  - 直接原因：category 结构中没有保存实例变量的字段
  - 为什么不加：对象的内存布局在编译期就已经定型了，由于 category 在运行时才被合并进原生类 ，这时候直接添加成员变量会破坏类原有的布局。（注意和后面的 Non-fragile ivars 做区分，父类的变更会体现在其结构体中，所以可以直接知道布局对不上，方便做处理，其实按道理可以做，但是不合算，不管是性能还是代码复杂度，只能说再次变更损耗性能）
  - 可以通过关联对象取代，关联对象主要实现原理是创建一个全局 map ，宿主对象地址和关联 map 以键值对的方式存储在这个 map 中，关联 map 保存这个宿主对象名下所有关联对象和对应的 key 。
- 注意和 Extension （匿名分类）的区别，Extension 其实是类的一部分，在编译期间和原生 class 共同组成实际的类结构体，category 是运行期拼进去的。

### iOS 的热更新方案有哪些？介绍一下实现原理。

<https://github.com/bang590/JSPatch/wiki/JSPatch-%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3>



###block 的原理，block 的属性修饰词为什么用 copy，使用 block 时有哪些要注意的？

- block 实例是一个**对象**，或者说一个结构体，这个结构体包含了**实现函数**以及一些**捕获变量**的信息。我们能接触到的有全局、堆、栈 block ，通常我们使用最多的是栈 block
- block 最核心的部分是对外部变量的捕获机制，我一般根据《是否会将捕获变量包装成对象、block 辅助函数是否有 retain 操作、包装对象辅助函数是否有 retain 操作》这三个依据来区分捕获变量的类型。

  - 非 __block 修饰
    - 基础类型
    - 对象指针类型
  - __block 修饰
    - 基础类型
    - 对象指针类型
      - MRC 
      - ARC
- **因为栈中的变量会随着栈帧销毁**，为了增强栈 block 的可用性，我们通常会在栈 block 销毁前将其拷贝为堆 block
- 使用 block 用注意循环引用，特别是不写 self 直接访问成员变量时，会有隐式循环引用

### 细致地讲一下事件传递流程

- 发生触摸事件
- 捕捉触摸事件线程 RunLoop 处理 source1，并设置主线程 RunLoop 对应的 source0 可处理
- 主线程 RunLoop 处理 source0
- 从 window 开始递归 subviews 查找触摸视图
- 将触摸事件由《 Application -> Window -> 触摸视图》路径派发给触摸视图
- 查看触摸视图和其父视图是否有 UIGestureRecognizer（UIGestureRecognizer 会影响关联视图及其子视图，比它们先一步拿到触摸事件），有 UIGestureRecognizer 则开始观察手势，匹配后由 UIGestureRecognizer 直接处理触摸事件，并取消 touches 系列回调；**无 UIGestureRecognizer 或者匹配到手势前**，将触摸事件发送给触摸视图响应链
  - 这里有个特例，**UIControl 不会被父视图关联的 UIGestureRecognizer "覆盖"**，所以 UIControl **父视图的** UIGestureRecognizer 不会影响到 UIControl 默认监听事件的处理，UIControl 会比父视图的 UIGestureRecognizer 先一步拿到触摸事件并进行处理，但直接往 UIControl 上加对应的 UIGestureRecognizer 还是会产生影响
- 响应链顺着《触摸 View -> 父 View  -> 控制器 (如果有) -> Window -> Application -> Application 代理》 路径（UIResponder 的 nextResponder 方法）查找触摸事件处理对象 （实现 touches 系列方法），并让此对象处理触摸事件。

### main()之前的过程有哪些

- 动态链接器完成运行环境初始化，配合 ImageLoader 将二进制文件加载到内存中
- 动态链接器调用 libSystem image 的初始化函数（`__attribute__((constructor))`），在初始化函数中调用 _objc_init
- _objc_init 绑定回调，在 image 加载到内存后，动态链接器通知 runtime 处理
- runtime 在 map_images 回调中读取类、分类、协议等信息，在 load_images 回调中遍历所有存在 +load 方法的类和分类，并调用它们的 +load 方法
- 初始化完成，动态链接器调用真正的 main 函数

### Category 中有 load 方法吗？load 方法是什么时候调用的？load 方法能继承吗？

- category 中有 load 方法吗？
  - 有
- 什么时候调用？
  - 在 load_images 回调时调用，也就是动态链接器执行对应的 image  的初始化函数时
- 能继承吗？
  - 不能，+load 方法有 runtime 自行调用，我们不能调 super
- 调用先后顺序：
  - 1 按照继承层级，从父类到子类调用 +load
  - 2 category 按照编译顺序调用 +load

### 讲一下你对 iOS 内存管理的理解

- 为什么要有内存管理

  - 对象内存**一般**分配到堆上，所以需要开发者手动去释放这部分内存，在传递对象时，对象创建者需要知道在什么时候去释放对象内存，iOS 采用**引用计数策略**管理对象内存，每个对象绑定一个计数器，这个计数器和对象的引用次数关联，引用次数变为 0 时，对象内存就会被释放。
- 内存管理的两个阶段

  - iOS 内存管理分 MRC 和 ARC 两个阶段，两者都是基于引用计数策略，MRC 需要开发者手动调用内存管理接口操作对象的引用计数值， ARC 则利用编译器在编译阶段生成中间语言时，根据程序上下文动态地插入内存管理代码。

- 比较关键的几个部分

  - ARC 属性关键字

    - assign (默认)  纯类型
    - strong (默认) 对象引用计数+1
    - weak 不改变对象引用计数，对象释放置 nil （weak 实现原理）
    - unsafe_unretained 不改变对象引用计数，对象释放不置 nil
    - copy 拷贝对象

  - 循环引用

    - 由于使用引用计数策略管理内存，不能很好地解决循环引用问题，所以需要我们开发时合理使用 weak 关键字来打破循环引用。

  - 自动释放池

    - 自动释放池主要用来延迟对象内存的释放，在自动释放池被弹出时，会向其中的对象发送 release 方法
    - autorelease 对象的释放时机按**是否为手动创建的自动释放池**，可以分为两种
      - 在 @autoreleasepool 作用域结束时释放
      - 在主线程 RunLoop 即将进入休眠以及即将退出 RunLoop 时释放
    - 自动释放池实际是**节点为 AutoreleasePoolPage 的双向链表**，其访问入口保存在 TLS (线程局部) 中。在新建 AutoreleasePool 时，会向尾节点 push 一个哨兵对象，在释放 AutoreleasePool 时会以这个哨兵对象为参照点，释放在哨兵对象之后加入的所有对象。所以在多个释放池嵌套时，其释放顺序和栈结构一致，先入后出。

    

### 你在项目中是怎么优化内存的？

- 大头还是内存泄漏，及时关闭不使用的资源，比如数据库，文件句柄，注意解决循环引用

- 循环创建临时对象时，使用自动释放池

- 图片采用 webp 代替 png / jpeg；接收内存警告时，去释放图片缓存；加载不需要在多个地方使用的图片时，使用 imageWithContentsofFile: 而不是 imageNamed: ，后者会缓存加载的图片，前者每次都从磁盘加载

- 对消耗资源较多的对象，尽量使用懒加载，使用时再申请内存

- 减少创建不必要的单例类，使用常规类代替

- 列表页合理复用视图，并且减少创建的 view 层级

    

### 讲讲 RunLoop，项目中有用到吗？

- 什么是 RunLoop

  - 一般来说一个线程一次只能执行一个任务，执行完就退出，为了能让线程尽可能多地处理事务且不退出，就需要引入 event loop （事件循环）机制。RunLoop 就是 iOS 提供事件循环机制，在 iOS 中 RunLoop 实际是一个对象，这个对象管理了需要处理的事件和消息，并且提供了一个入口函数执行事件循环逻辑，线程执行这个函数后，就会进入"接受消息-> 等待->处理"的循环中，直到这个循环结束，函数返回。

- 和线程的关系

  - 线程和 RunLoop 是一一对应的关系，其关系以线程标识为 key，以 RunLoop 对象为 value 保存在一个全局字典中。并且线程中的 RunLoop 是懒加载的，其创建发生在第一次获取时。

- 常见的几种 mode

  - RunLoop 的 **mode 是用来管理 source/timer/observer** 的，每次运行时只能指定一个 mode ，切换时需要退出再重新指定 mode 运行，当事件发生时，RunLoop 会让当前 mode 下对应的 source/timer/observer 来处理事件调用回调，如果**当前 mode 没有 source/timer ，则 RunLoop 直接退出**。
  - kCFRunLoopDefaultMode 和 TrackingRunLoopMode 是公开的两个 mode ，还有一个 Common 标记字符串 kCFRunLoopCommonModes  ，外界指定 kCFRunLoopCommonModes 添加的 source/timer/observer 会被同步到 Common 标记的 mode 中，刚才说的的两个 mode 都是 Common 属性，所以指定 kCFRunLoopCommonModes 添加的 NSTimer 可以在列表滚动时也生效。

- 处理事件顺序

  - 通知 observer 即将进入 loop
  - |------------------loop ---------------------|
  - 通知 observer 将要处理 timer
  - 通知 observer 将要处理 source0
  - 处理 source0
  - 如果有 source1，跳到处理唤醒消息步骤
  - 通知 observer 线程即将休眠
  - 休眠等待唤醒  (基于port的source事件、timer 时间到、runloop 超时时间到、手动唤醒)
  - 处理唤醒消息  (处理 timer 、dispatch 到 main queue 、source1事件)
  - |------------------loop ---------------------|
  - 通知 observer 即将退出

- 项目中用到的

  - 运行 NSTimer / CADisplayLink 
  - 旧版本 AFNetworking 中的常驻线程 ，由于 NSURLConnection 需要使用 RunLoop 执行注册的 source0，所以需要线程有运行起来的 RunLoop 去处理事件，新版本使用 NSURLSession 不需要。

- 开发 App 中隐式用到的

  - AutoreleasePool

    - 主线程在 App 启动后，在主线程 RunLoop 中注册了两个 Observer，一个**监听准备进入 RunLoop**，在回调中创建自动释放池；一个**监听即将进入休眠和即将退出RunLoop**，在即将进入休眠时，**释放旧池创建新池**，在即将退出RunLoop 时，释放旧池

  - performSelector

    - 创建 timer 到对应的线程

  - GCD dispatch 到 main queue

  - 事件响应

    - 苹果会在主线程会注册 source0 ，在捕获触摸事件线程注册 source1，在 source1 回调中触发这个 source0 的回调，然后派发给 UIApplication

    

### 列表卡顿的原因可能有哪些？你平时是怎么优化的？

- 没有重用 cell 
  - 重用 cell
- cell 回调中频繁执行高度，字符串长度计算
  - 缓存计算的结果，复用时直接使用
- 使用了圆角或者遮罩等会触发离屏渲染的属性
  - 在后台线程预先绘制好后显示

优化手段：

- 性能敏感的页面不使用 xib 和 autolayout ，可以使用 frame
- 只处理滑动目标节点附近的几个 cell，略过滑动过程的 cell 
- 文本异步渲染 YYAsyncLayer
  - 需要显示内容时，向 UIView delegate 请求异步绘制任务，异步任务完成后以图片的形式设置回 content
- 对于不需要响应触摸事件的组件，可以使用图层预合成方法，将多个 layer 合并渲染成一张图片

### 项目有没有做过组件化？或者你是否调研过？

- 业界基于 cocoapods 常用的组件化方式有两种

  - 基于中介者和反射
    - 组件通过中介者通信，中介者通过 runtime 接口解耦，通过 target-action 简化写法，target 代表模块，action 代表模块能提供的服务，通过 category 作为具体中介者分离组件接口代码
  - 基于 url 注册表
    - 用 url 表示接口，在模块启动时注册模块提供的接口，调用时用 url 找注册模块的接口

- 相同点

  - 思路都是中介者不能直接去调用组件方法，会产生依赖，这时候就需要**通过 字符串 -> 方法 这种映射形式去调用**。可以通过 runtime 的 `className 和 selectorName -> IMP` ，也可以通过注册表的 `key -> block` ，前一种是 OC 自带特性，后一种需要维持注册表，不必要

- 优劣

  - 基于 url 注册表
    - 首先要说明的是，组件化跟使用 url 并没有什么关系，任何组件化方法都可以再加一层url router 解决 url 需求，这里说明的是基于 url 注册表这种直接使用url 实现组件化，而不是组件化后再加一层会有什么问题
    - 内存需要保存一份表，组件多了会有内存问题
    - 远程调用依赖本地调用，导致传递参数限制，需要提供额外的方案来补全
      - 比如 protocol-class 方案，而这种方案不是直接通过中介者调用组件方法，而是通过中介者拿到组件对象，再自行去调用组件方法，会导致调用分散问题，没有统一入口
    - 直接使用 URL 参数的格式没有使用 category 明确，category 可以借助语法提示明确组件的方法和参数类型

  

### 讲一下 OC 的消息机制

- OC 消息机制阶段
  - 消息发送
  - 消息转发
- 消息发送
  - 消息发送指的是 runtime 通过 selector 快速查找 imp 的过程，所有的消息发送动作，都会转化成 objc_msgSend 函数，查找 imp 顺序：
    - 类的调用方法 cache 列表
    - 类的方法列表
    - 类的父类方便列表
- 消息转发
  - 消息转发是 runtime 在查找 imp 失败后提供的挽救机制，分为三步
    - lazy method resolution 
      - 这一步调用了-resolveMethod: 系列方法，供开发者动态添加 sel 的实现，返回 NO 会进入第二步。这一步可以很方便地和 @dynamic 属性结合，比如 CoreData，它实际的实现是访问数据库
    - fast forwarding path
      - 这一步调用了 -forwardingTargetForSelector: 方法，供开发者提供其他可以响应的对象，如果返回 nil/self 之外的对象，那么会重启一次消息发送动作给返回的对象，否则进入第三步。
    - normal forwarding path
      - 这一步调用了 -forwadingInvocation: 、-methodSignatureForSelector: 方法，这一步将消息的所有信息保存在一个 NSInvocation 中，供开发者使用。这个 NSInvocation 对象包含参数、发送目标及 sel 等信息，尤其是参数信息，所以这一步也是可操作性最强的一步。如果 -methodSignatureForSelector: 没有返回有效的方法签名，消息转发失败，抛出异常
  - 消息转发的应用
    - 消息转发越靠后灵活性越大，性能损耗也越大
    - 第一步：CoreData
    - 第二步：weak proxy、delegate proxy
    - 第三部：NSUndoManager 保存调用上下文、aspect hook 所有方法、AppDelegate 初始化方法拆分

### ARC 都帮我们做了什么？

- 帮我们在编译生成中间代码时，根据程序上下文自动插入内存管理函数

### 实现 isEqual 和 hash 方法时要注意什么？

- isEqual 和 hash 需要同时重写
- 保证 isEqual 和 hash 的一致性
  - 比如 isEqual 取决于某两个属性的比较结果，hash 就不能直接调用 [super hash]，可以使用这两个属性 hash 的位或运算结果作为 hash 值

### property 的常用修饰词有哪些？weak 和 assign 的区别？weak 的实现原理是什么？

- 有哪些关键字
  - 原子性: atomic（默认）、nonatomic （无法保证绝对的线程安全，比如一个线程读，一个线程写）
  - 读写权限：readwrite（默认）、readonly
  - 内存管理语义：assign（默认）、strong（默认）、weak、unsafe_unretained、copy
  - 方法名：getter=、setter=
- weak 和 assign 的区别
  - weak 和 assign 在修饰对象时，都不会增加设置对象的引用计数，但是在销毁时，weak 会置 nil 对象指针，assign 不会。并且 assign 可以修饰非 OC 对象，weak 必须用于 OC 对象
  - ARC 下，修饰对象时，assign 和 unsafe_unretained 作用其实是相同的，但是 unsafe_unretained 和 weak **表意更加清晰**，都表示一种非拥有关系
- weak 实现原理
  - 设置 weak 修饰的变量或属性时，runtime 会以赋值对象地址的 hash 值为 key ，以包装 weak 修饰的指针变量地址的 entry 为 value，放入全局 weak hash table 中，当赋值对象释放时，runtime 会在目标对象的 dealloc 处理过程中，以对象地址 hash 值为 key 去 weak hash table 中查找 entry，然后置空 entry 指向的所有对象指针。
    - entry 结构使用数组来保存那些 weak 修饰的，指向目标对象的指针变量地址，有趣的是，在只有不超过4个 weak 修饰的指针变量指向同一个对象时，对象对应的 entry 中的数组是个普通的内置数组，超过4个之后，这个数组就会扩充成一个 hash table （空间和时间的权衡）

### 线程安全的处理手段有哪些？把你想到的都说一下。

- 如何编写线程安全代码
  - 多使用 immutable 不可变对象，如果要变更，返回新的对象
  - 函数可重入，比如少用静态变量和全局变量，去除使函数产生副作用代码(纯函数)
  - 共享资源需要利用同步和锁机制
  - 利用 TLS （线程局部存储），如果变量需要对线程内所有函数都可见的话，正常的话需要使用全局变量（map：pthread_t + 变量地址），AutoreleasePool 就使用了 TLS 保存链表的 hotPage ，即链表尾节点

- 锁
  - 互斥锁
    - 主动睡眠，让出时间片，相比一元信号量，**互斥锁只能由上锁的线程解开**，更强调**资源使用权**，信号量更**强调资源数量**；
  - 递归锁
    - 主动睡眠，让出时间片，一个线程可多次获取同一个递归锁，不会产生死锁
  - 自旋锁
    - 死循环判断锁变量，如果锁保护代码执行时间长，不宜用自旋锁，耗费 CPU 时间片
  - 信号量
    - 主动睡眠，让出时间片，初始时设置好资源数量，访问资源减1，释放资源加1，大于0即不阻塞，和互斥锁不同的时，一元信号量可以由任一线程解开
  - 读写锁
    - 主动睡眠，让出时间片，读锁允许多个线程同时读，写锁同一时刻只允许一个线程写
    - 读 读 不阻塞
    - 读 写 阻塞
    - 写 写 阻塞
    - 写 读 阻塞
  - 条件变量
    - 主动睡眠，让出时间片，解决的问题不是互斥，而是**等待**，比如生产消费模型，多个线程等待同一个线程中的任务结束
    - 需要配合互斥锁使用，保证操作数据安全
      - **使用 while 检测要操作的内容**（等待信号和发送信号操作先后的问题，需要确保等待信号时，发送信号还没执行）
      - **和互斥锁配合使用**（涉及到内容的检测，那么应该用锁保证检测数据的安全）
  - @synchronized
    - 对象哈希值为 key ，递归锁为 value 的哈希表

### 说一下 OperationQueue 和 GCD 的区别，以及各自的优势

- 语言构成
  - GCD 由 C 语言提供 API，OperationQueue 在 GCD 的基础上包装的 OC 对象
  - GCD 更加轻量，效率更好，OperationQueue 作为一个对象更易用，代码复用度更高
- 未执行任务取消
  - GCD 取消任务需要比 OperationQueue 写更多代码 (使用 GCD 接口创建的 block 可以使用 GCD 接口取消，或者用外部变量)，OperationQueue 直接执行 cancel 即可
- 任务依赖关系
  - GCD 没有提供设置任务依赖关系接口，OperationQueue 能够很方便地设置任务依赖关系
- 任务进度监听
  - OperationQueue 的 NSOperation 对象支持 KVO，可以很方便地监听任务状态 (ready, executing, finished, cancelled)
- 优先级设置
  - OperationQueue 能够很方便地设置任务优先级，GCD 需要使用其 API 创建的任务 block 才能比较方便地设置任务优先级
- 代码复用
  - 使用 OperationQueue 能继承 NSOperation 添加成员变量与方法，提高代码复用度，比 GCD 简单地将 block 任务添加至队列封装性更好，能添加更多自定义功能

### Swift 中 struct 和 class 的区别

- struct 值类型，class 引用类型
  - 值类型存放在栈中，变量本身拥有数据，引用类型存放在堆中，变量为指向实际数据的指针
- struct 由于是值类型，无法继承，class 可以
- struct 由于是值类型，用 let 创建时不可变，class 可以
- struct 由于是值类型，内部方法改变属性时需要加 mutating ，class 不用
- struct 提供默认初始化所有属性的初始化方法，class 没有

### Swift 和 OC，各自的优缺点有哪些？

- 优点
  - swift 为类型安全语言，更加安全，可以在编译时检查出更多问题
  - swfit 代码更少，语法简洁，省区大量冗余代码
  - swfit 速度更快，性能更高
- 缺点
  - 版本不稳定，5.0 之后稳定
  - 在有稳定 abi 前，使用 swift 会增大包大小 (需要嵌入编译的swift库)
  - OC 部分运行时在 swift 中无效

### 如果让你实现 NSNotificationCenter，讲一下思路

- 简述
  - 以 block 接口为例，NSNotificationCenter 单例维护一个 map，这个 map 的 key 为notification name 和匹配 object 创建的自定义对象，value 是元素为 block 的 set 集合。发送通知时，根据 name 和 object 去 map 中查找 block 集合并传入 notification 执行，实际为了匹配添加时 name 和 object 为 nil 的情况，发送通知时会先后以 name object、 name nil、nil object、nil nil 的形式去 map 查找。

- 结构
  - 一个全局 map
- key
  - 通知 name  和 object 组成的类实例
  - 这个 object 表示只有发送对象和 object 对应上时，才出发回调
  - 注意 name 为 nil 时表示接收所有通知， object 为 nil 时表示接收 name 的所有通知，key class 的 isEqual 要考虑这一点，hash 方法返回两个成员变量的 hash 位异或值
- value
  - block set 集合 （如果是 observer + selector ，可以包装成 NSObserver ，事实上，block 包装成 NSObserver 有利于代码统一）
- -postNotification: 要注意覆盖全 case ，调用四次 -postNotification:name:object
  - name object
  - name nil
  - nil object
  - nil nil

### 如果让你实现 GCD 的线程池，讲一下思路

- 简述
  - 首先分三个部分：线程池需要的状态变量，线程池入口，线程运行函数
  - 线程池一般都需要已创建线程数，正在执行线程数，最大线程数这几个状态变量来决定是否创建新线程，然后需要**条件变量实现生产消费模型**，让线程能在没有任务的时候休眠，有任务的时候唤醒执行，由于条件变量需要和互斥锁一起工作，所以还要有互斥锁
  - 线程池主要职责为提交任务并执行，所以简单地设置一个添加任务的入口，在添加任务时，**判断当前任务数量和空闲线程数大小以及已创建线程和最大线程数大小，如果需要的话 detach 一个新的线程，增加已创建线程数，接着给条件变量发送 signal** ，这一块操作都由互斥锁保证安全
  - 线程运行函数主要是一个**死循环**，在循环体里面**判断任务是否为空，如果为空，就 wait 条件变量，也就是进入休眠状态，等待唤醒，如果不为空就取出一个任务，并执行**，同时变更线程池的正在执行任务线程数这些状态变量，这部分操作也由互斥锁保证安全

- 线程池职责
  - 提交任务，执行任务
- 线程数相关
  - 已创建线程数量	
  - 正在执行任务线程数量
  - 最大线程数量
- 锁相关
  - 条件变量 + 互斥锁
- 线程创建方式
  - detach
  - 死循环

### 为什么是三次握手？为什么是四次挥手？三次挥手不行吗？

- 三次握手
  - 在不可靠的信道上，通信双方需要对某个问题达成一致，三次通信时理论上的最小值，所以三次握手不是 TCP 本身的要求，而是为了满足"在不可靠信道上可靠地传输信息"这一要求导致的
- 四次挥手
  - TCP 是全双工的，需要有两次"请求断开——确认"的步骤 client 到 server ，server 到 client 的连接断开。三次握手中间那次握手，把 SYN 和 ACK 合并了，**四次挥手把 FIN 和 ACK 分开是考虑到服务端在发送 FIN 前，可能还需要给客户端发送数据**。

### 讲一下 HTTPS 密钥传输流程

- 客户端向服务端发起请求，携带随机数
- 服务端发送证书给客户端，携带随机数
- 客户端使用本地权威机构的公钥验证证书，获取服务端公钥
- 客户端生成随机数，并使用服务端公钥加密，发送给服务端
- 服务端使用私钥解密，获得随机数
- 两端都有三个随机数，根据这三个随机数协商生成对称密钥
- 加密通道完成，使用对称密钥通信

### 讲讲 MVC、MVVM、MVP，以及你在项目里具体是怎么写的？

- MVC
  - 

### iOS 系统框架里使用了哪些设计模式？至少说6个。

- 命令
  - NSInvocation
- 中介者
  - MVC
- 抽象工厂模式
  - NSArray、NSDictionary、NSString、NSNumber
- 观察者
  - KVO
- 委托
  - delegate
- 单例
  - file manager, notification center
- 责任链
  - 响应链
- 享元
  - cell 复用

### 你自己用过哪些设计模式？

- 策略
  - 图片浏览器
- 代理
  - 选择器代理
  - 代理和装饰的区别：代理强调让别人帮你去做一些本身与你业务没有太多关系的职责，对代理对象施加控制；装饰强调增强自身，被装饰后，能在被增强的类上使用增强后的功能
- 委托
  - 自定义 delegate
- 中介者
  - 组件化解耦
- 单例

### 哪一个项目技术点最能体现自己的技术实力？具体讲一下。

- 组件化 cocoapods 插件
  - 组件粒度二进制切换
- 组件自动化发布平台
- 组件生命周期管理

### 你在项目中遇到的最大的问题是什么？你是怎么解决的？

- 组件发版时的发布问题

### 用 Alamofire 比直接使用 URLSession，优势是什么？

- 在构建请求和解析请求时，三方网络库帮我们处理了大部分工作，让我们可以比较方便地构建
- 直接使用 URLSession 也需要做一层封装，既然如此，对成熟的三方网络库封装工作量少，且不易出错

### 你是如何学习 iOS 的?

### 和产品经理、测试产生冲突时，你是怎么解决的？

### 手写一下快排

### 遍历一个树，要求不能用递归

### 找出两个字符串的最大公共子字符串