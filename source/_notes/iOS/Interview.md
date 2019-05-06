### 你在项目中用过 runtime 吗？举个例子

##### 项目中用的

- AppDelegate 初始化方法拆分

  - 替换 setDelegate 方法，并且在消息转发的 forward invocation 阶段向注册的模块转发代理消息
  - 通过上述方法实现组件接入即可用，即使使用改组件的壳工程没有实现对应的代理方法，组件也可以接收到代理消息

- Week Proxy

  - 弱引用实际对象，在 forward target 阶段，把消息转发给这个对象
  - 比如 NSTimer / CADisplayLink 会持有 target ，用 week proxy 包装一层避免循环引用

- Delegate Proxy

  - 弱引用实际对象，在 forward target 阶段，把部分不使用的代理消息转发给这个对象
  - 比如我们的表单组件用了 tableView 的部分代理方法，就可以用 Delegate Proxy 把不使用的 tableViewDelegate 和 scrollViewDelegate 的代理方法转发出去，不用写胶水代码 

##### 系统/三方中用的

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

###  Category 的实现原理，以及 Category 为什么只能加方法/属性，不能加实例变量

- category 是什么？
  - category 实际上是方法、属性、协议的集合体，保存在 category_t 结构体中
- class 怎么合并 category？
  - 合并分两个时间点。category 和 class 一样，编译之后会以全局变量的形式保存在 DATA 段中，在 objc init 阶段，runtime 会在处理 image 的回调函数 read_image 中，去 DATA 段读取所有的 category ，

