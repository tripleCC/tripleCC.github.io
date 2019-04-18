基本原理： [Block 技巧与底层解析](<https://triplecc.github.io/2015/07/19/2015-08-27-blockji-qiao-yu-di-ceng-jie-xi/>) （文章中没有说明 ARC 对 `__block` 修饰对象指针捕获的影响，这里完善这部分内容）

### 什么是 Block

block 实例是一个**对象**，这个对象包含了**实现函数**以及一些**捕获变量**的信息，一般情况下，其 isa 指向常见的三个类：

- _NSConcreteGlobalBlock （全局）
- **_NSConcreteStackBlock**（栈）
- _NSConcreteMallocBlock（堆）

通常我们使用最多的是栈 block ，上方所说的全局、栈、堆表示对应的 **block 对象内存所在区域**。

### Block 拷贝

**因为栈中的变量会随着栈帧销毁**，为了增强栈 block 的可用性，我们通常会在栈 block 销毁前将其拷贝为堆 block。 为什么不直接使用堆 block 呢？因为每次都在堆上直接为 block 开辟新的内存空间会影响程序性能。

block **拷贝和释放时会触发辅助函数**，辅助函数主要作用是管理结构中的捕获变量。辅助函数有两种：

- block 的辅助函数，主要负责管理结构中的捕获变量
  - 调用顺序：block 拷贝函数 -> block 辅助函数
- 包装对象的辅助函数，主要负责管理包装对象中，捕获的对象指针变量指向对象的管理
  - 调用顺序：block 拷贝函数 -> block 辅助函数 -> 包装对象辅助函数

第二种辅助函数只有使用 **`__block` 修饰对象指针**时才会生成。

### 外部变量捕获

根据捕获时内部实现的异同，大体可以根据变量类型分为以下几种：

- 非 __block 修饰
  - 基础类型
  - 对象指针类型
- __block 修饰
  - 基础类型
  - 对象指针类型
    - MRC 
    - ARC

分类的依据如下：

- 是否会将捕获变量包装成对象
  - block 辅助函数是否有 retain 操作
    - 包装对象辅助函数是否有 retain 操作

### 非 __block 修饰变量的捕获

重写后的 block 结构中，会有一个字段对应着捕获的变量，反应到内存中，就是 **block 内存片段中有一块内存保存着捕获变量的值**。

在 block 进行拷贝时，会有辅助函数负责拷贝捕获变量字段的值，**如果捕获的变量为对象指针，辅助函数还会去 retain 指针指向的对象**。

### __block 修饰的变量的捕获

> 包装对象：__block 修饰的变量被包装后的结构

重写后的 block 结构中会有一个字段指向此包装对象， block 拷贝到堆后，包装对象也会通过 block 辅助函数从栈拷贝到堆。

为什么不让所有的变量都默认 `__block`？因为 `__block` 修饰的变量需要额外的开销。

由于 `__block` 修饰的变量可以在 block 中被赋值 ，为了实现栈和堆中捕获变量访问的一致性，`__block` 修饰后的变量会被包装成一个对象结构。所有的访问都通过这个结构中的 `forwording` 字段，并且栈和堆中包装对象的 `forwording` 字段值相同，都指向堆中的包装对象，实际访问时通过 `structure -> forwording -> captured variable`。

![block___block_variable](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/block___block_variable.png)

由此可以得到下面代码的输出结果：

```objective-c
__block int i = 0; // 实际访问的是 structure->forwording->i，我们可以视为 p_i = &i，后面操作都是针对 *p_i 
int j = 0; // 直接挂在 block 结构的字段中，不会感知后续栈中的变更
void (^block)(void) = ^{ printf("%d %d\n", i, j); };
j = i = 1;
block();
// 1 0
```

### ARC 对 __block 修饰对象指针的影响

> block 通过包装对象的辅助函数管理对象指针指向的对象

MRC 时代，block 在捕获  `__block` 修饰的对象指针时，不会 retain 其指向的对象（见 `_Block_object_assign` 函数第一个分支，由包装对象的辅助函数调用），**所以在 MRC 时代，`__block` 是可以直接用来解决循环引用的**。为什么不 retain 的原因在 [Why are __block variables not retained (In non-ARC environments)?](https://stackoverflow.com/questions/17384599/why-are-block-variables-not-retained-in-non-arc-environments) 有提及，简单来说就是因为 `__block` 修饰的对象指针在 block 内可被赋值，在 ARC 推出之前，针对对象指针重赋值时对象的内存管理问题，没有找到合适的方法解决。

ARC 时代，block 在捕获 `__block` 修饰的指针对象时，就会 retain 其指向的对象了，不过我们还是可以**用 `__block` 间接解决循环引用——在 block 中将对象指针置 nil**，一般很少会这么用，因为 ARC 时代的 `__weak` 可以更好地解决这个问题。

上面所说的**对象 retain 操作，都是发生在 block 的拷贝阶段**（辅助函数的实现中），[ARC 中 block 的自动拷贝](<https://stackoverflow.com/questions/23334863/should-i-still-copy-block-copy-the-blocks-under-arc>) 中提到， ARC 环境中，block 的 copy 操作在被强引用等大部分情况下都会自动执行，所以不需要我们手动调用。 

MRC 和 ARC 生成包装对象的辅助函数决定了是否对对象进行 retain 操作，[confusion on __block NSObject *obj and block runtime](https://stackoverflow.com/questions/36993379/confusion-on-block-nsobject-obj-and-block-runtime) 回答对此辅助函数的生成做了较详细的解读，它们的伪代码如下：

```objective-c
// clang rewrite 使用的是 MRC ，并且要看 ARC 处理之后的代码，需要利用 llvm 生成 IR / 汇编代码之后查看 
//
// MRC
// BLOCK_BYREF_CALLER 标识会导致 __Block_object_assign 直接执行赋值操作后就返回
___Block_byref_object_copy_(dst, src) {
    __Block_object_assign(&dst->var, src-var, BLOCK_BYREF_CALLER | BLOCK_FIELD_IS_OBJECT)
}

// ARC
// 堆中的包装对象接管 __block 修饰的指针变量指向的对象
___Block_byref_object_copy_(dst, src) {
    objc_storeStrong(&dst->var, src->var)
    objc_storeStrong(&src->var, nil)
}
```

其中 ARC 环境下，相关对象的引用图如下：

![block___block_object_pointer](<https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/block___block_object_pointer.png>)

这里我们通过控制包装对象的引用计数，来保证在捕获对象指针变量的 block 没有全部释放前提下，其指向的对象将不会被释放，所以我们只需要保证包装对象的引用计数正确即可，后续拷贝也只是增加包装对象的引用计数，这点和非 `__block` 修饰的指针变量还是有区别的，后者是直接增加指针变量指向对象的引用计数。

