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
- 文本异步渲染 YYText，YYAsyncLayer
- 对于不需要响应触摸事件的组件，可以使用图层预合成方法，将多个 layer 合并渲染成一张图片

### 项目有没有做过组件化？或者你是否调研过？

看下 [这个](<https://blog.cnbang.net/tech/3080/>) 总结下，结合自己项目

### 讲一下 OC 的消息机制



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

### 说一下 OperationQueue 和 GCD 的区别，以及各自的优势

### Swift 中 struct 和 class 的区别

### Swift 是如何实现多态的？

### Swift 和 OC，各自的优缺点有哪些？

### 如果让你实现 NSNotificationCenter，讲一下思路

### 如果让你实现 GCD 的线程池，讲一下思路

### 为什么是三次握手？为什么是四次挥手？三次挥手不行吗？

### 讲一下 HTTPS 密钥传输流程

### 讲讲 MVC、MVVM、MVP，以及你在项目里具体是怎么写的？

### iOS 系统框架里使用了哪些设计模式？至少说6个。

### 你自己用过哪些设计模式？

### 哪一个项目技术点最能体现自己的技术实力？具体讲一下。

### 你在项目中遇到的最大的问题是什么？你是怎么解决的？

### 用 Alamofire 比直接使用 URLSession，优势是什么？

### 你是如何学习 iOS 的?

### 和产品经理、测试产生冲突时，你是怎么解决的？

### 手写一下快排

### 遍历一个树，要求不能用递归

### 找出两个字符串的最大公共子字符串