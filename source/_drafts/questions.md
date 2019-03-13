#### @property中有哪些属性关键字？

1. 原子性: atomic（默认）、nonatomic （无法保证绝对的线程安全，比如一个线程读，一个线程写）
2. 读写权限：readwrite（默认）、readonly
3. 内存管理语义：assign（默认）、strong（默认）、weak、unsafe_unretained、copy
4. 方法名：getter=、setter=

内存管理语义：

- assign 纯类型

- strong 对象引用计数+1

- weak 不改变对象引用计数，对象释放置 nil

- unsafe_unretained 不改变对象引用计数，对象释放不置 nil

- copy 拷贝对象



#### @synthesize和@dynamic分别有什么作用

在实例变量/存取方法没创建时：

- @synthesize：告诉编译器生成存取方法和实例变量
- @dynamic：告诉编译器不要生成存取方法和实例变量，这些方法会在运行时提供（编译不出错）
  - 涉及到消息转发第一步 resolve method，可以在这个过程中动态添加方法，如 CoreData 的数据库访问

#### @synthesize合成实例变量的规则，及使用场景

合成规则:

- 如果指定名称，会生成一个指定名称的成员变量
- 如果成员变量已存在，则不再生成

自动合成：

- 编译器会自动加上以下语句

  ```
  @synthesize propertyName = _propertyName
  ```

  

不会自动合成的场景：

1. 同时重写了 setter 和 getter 时

2. 重写了只读属性的 getter 时

3. 使用了 @dynamic 时

4. 在 category 中定义的所有属性

5. 在 @protocol 中定义的所有属性

6. 重载的属性
  

以上除了3、4，其他情况都可以使用 @synthesize 合成实例变量，还可以使用 @synthesize 自定义实例变量名

#### @property声明的NSString（或NSArray，NSDictionary）经常使用copy关键字，为什么

赋值给属性的可能是可变子类对象（NSMutableString、NSMutableArray、NSMutableDictionary），为了让对应的属性不受外界变动的影响，需要做一份拷贝

对于 copy 操作的深浅赋值：

```
[immutableObject copy] // 浅复制
[immutableObject mutableCopy] //深复制/单层深复制
[mutableObject copy] //深复制/单层深复制
[mutableObject mutableCopy] //深复制/单层深复制
```

如果对象是不可变的，那 copy 时不需要拷贝内容，因为外界无法修改原对象从而影响到 copy 后的对象指针

#### objc中向一个nil对象发送消息将会发生什么？

是有效的，会返回 0

发送消息时，发现对象是 (id)0，无法访问其 isa  ，就直接返回了

#### 什么时候会报unrecognized selector的异常

向对象发送消息时，此对象所属类的方法列表中没有对应的方法，并且没有在消息转发三部曲中提供有效的补救措施

[Objective-C 消息转发应用场景摘录](https://triplecc.github.io/2017/07/09/2017-07-09-objective-cxiao-xi-zhuan-fa-ying-yong-zhi-ji-chu/)

#### runtime 如何实现 weak 属性

设置 weak 修饰的属性时，runtime 会生成对应的 item pair 放入 weak hash table 中，以实例变量的值（赋值对象地址）为 key，以实例变量地址为 value。当实例变量，即对象指针，指向的对象释放时，runtime 会在目标对象的 dealloc 处理过程中，以自身地址为 key 去 weak hash table 查找 value ，置空 value 指向的对象指针，即 `*value = nil`

```
// 设置 weak 修饰的实例变量流程
_object_setInstanceVariable
-> _object_setIvar
	-> objc_storeWeak
		-> storeWeak
			-> weak_unregister_no_lock

// dealloc 处理 weak 引用流程
objc_destructInstance
-> clearDeallocating
	-> sidetable_clearDeallocating
		-> weak_clear_no_lock
```

#### 