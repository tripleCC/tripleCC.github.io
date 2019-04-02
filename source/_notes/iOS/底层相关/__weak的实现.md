### __weak的实现

详情查看： [Objective-C weak 弱引用实现](<https://triplecc.github.io/2019/03/20/objective-c-weak-implement/>) 。

### 原理简述

设置 `__weak` 修饰的变量时，runtime 会生成对应的 entry 结构放入 weak hash table 中，以赋值对象地址生成的 hash 值为 key，以包装 `__weak` 修饰的指针变量地址的 entry 为 value，当赋值对象释放时，runtime 会在目标对象的 dealloc 处理过程中，以对象地址（self）为 key 去 weak hash table 查找 entry ，置空 entry 指向的的所有对象指针。

实际上 entry 使用数组保存指针变量地址，当地址数量不大于 4 时，这个数组就是个普通的内置数组，在地址数量大于 4 时，这个数组就会扩充成一个 hash table。

