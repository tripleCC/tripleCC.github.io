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
  - 为什么不加：对象的内存布局在编译期就已经定型了，由于 category 在运行时才被合并进原生类 ，这时候直接添加成员变量会破坏类原有的布局。（注意和 Non-fragile ivars 做区分，父类的变更会体现在其结构体中，所以可以直接知道布局对不上，方便做处理，其实按道理可以做，但是不合算，不管是性能还是代码复杂度）
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