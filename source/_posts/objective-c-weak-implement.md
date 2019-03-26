---
title: Objective-C weak 弱引用实现
date: 2019-03-20 14:22:14
tags: [Interview,Objective-C]
---

在编写代码时，弱引用一般以下面两种形式出现：

- 使用 `weak` 关键字修饰属性时
- 使用 `__weak` 关键字修饰变量时

这里我们可以统一把第一种形式看作使用 `__weak` 关键字修饰成员变量。

`__weak` 修饰的变量有两大特点：

- 不会增加指向对象的引用计数 （规避循环引用）
- 指向对象释放后，变量会自动置 nil （规避野指针访问错误）

下文会从源码的视角分析 runtime 是如何实现弱引用自动置 nil 的。
<!--more-->
## 实现简述

设置 `__weak` 修饰的变量时，runtime 会生成对应的 entry 结构放入 weak hash table 中，以赋值对象地址生成的 hash 值为 key，以包装 `__weak` 修饰的指针变量地址的 entry 为 value，当赋值对象释放时，runtime 会在目标对象的 dealloc 处理过程中，以对象地址（self）为 key 去 weak hash table 查找 entry ，置空 entry 指向的的所有对象指针。

实际上 entry 使用数组保存指针变量地址，当地址数量不大于 4 时，这个数组就是个普通的内置数组，在地址数量大于 4 时，这个数组就会扩充成一个 hash table。

## 实现模仿

首先，我们看下如下代码：

```objc
@interface A : NSObject
@end
@implementation A
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __unsafe_unretained NSObject *w1;
        @autoreleasepool {
            NSObject *obj = [A new];

            w1 = obj;
        }
        NSLog(@"%@", w1);
    }
    return 0;
}

// EXC_BAD_ACCESS
```
由于 `__unsafe_unretained` 修饰的变量会始终保留对像地址，所以在 obj 指向的对象释放后，访问 w1 会出现 EXC_BAD_ACCESS 错误，我们要做的就是模仿 `__weak` 的实现，在 obj 指向的对象释放之后，将 w1 置为 nil。

以下是根据实现简述编写的代码：

```objc
// { 对象地址 : [ 对象指针地址1、 对象指针地址1] }
static NSMutableDictionary *weakTable;
@interface A : NSObject
@end
@implementation A
- (void)dealloc {
    // 获取指向此对象的所有指针变量地址
    for (NSNumber *ptrPtrNumber in weakTable[@((uintptr_t)self)]) {
        // 根据指针变量地址，将指针变量置为 nil
        // 这里就是 w1 置 nil
        uintptr_t **ptrPtr = (uintptr_t **)[ptrPtrNumber unsignedLongValue];
        *ptrPtr = nil;
    }
    // 移除和此对象相关的数据
    [weakTable removeObjectForKey:@((uintptr_t)self)];
}
@end
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        weakTable = @{}.mutableCopy;
        __unsafe_unretained NSObject *w1;
        @autoreleasepool {
            NSObject *obj = [A new];
            uintptr_t objAddr = (uintptr_t)obj;

            w1 = obj;
            // 将对象地址和需要自动置 nil 的指针变量的地址保存至 map 中
            // 使用可变数组方便处理多个需要置 nil 的变量指向 obj
            weakTable[@(objAddr)] = @[@((uintptr_t)&w1)].mutableCopy;
        }
        NSLog(@"%@", w1);
    }
    return 0;
}

// (null) (null)
```
考虑到 w1 变量的作用域可能会在指向对象释放前结束，我们还需要在作用域结束时，将保存的 w1 地址清除：

```objc

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSObject *obj = [A new];
        weakTable = @{}.mutableCopy;
        {
            __unsafe_unretained NSObject *w1;
            uintptr_t objAddr = (uintptr_t)obj;

            w1 = obj;
            weakTable[@(objAddr)] = @[@((uintptr_t)&w1)].mutableCopy;
            // 即将走出 w1 所在作用域，将 w1 的地址从 map 中清除
            [weakTable[@((uintptr_t)w1)] removeObject:@((uintptr_t)&w1)];
        }
        
    }
    return 0;
}
```
即使出了作用域，只要栈帧还在，并且 w1 变量所处的地址没被覆盖，那么通过 w1 的地址访问 w1 变量（即访问 obj 指向的对象）还是没有问题的，只不过既然 w1 对于外界不可见，就没有继续在 map 中维护其地址的必要了。

以上就是我所理解的弱引用置 nil 的粗略实现，接下来我们看看 runtime 是如何实现这个特性的。

## objc 的实现

> 以下源码分析基于 runtime 750 版本

我们使用以下代码分析 runtime 是如何在 weak hash table 中创建及销毁 `__weak` 修饰变量信息的：

```objc
int main(int argc, const char * argv[]) {
    __weak NSObject *w0;

    @autoreleasepool {
        NSObject *obj = [A new];
        w0 = obj;
        {
            __unused __weak NSObject *w1 = obj;
        }
    }
    return 0;
}
```

### 初步分析

在设置 w1/w0 变量时，runtime 触发了以下调用栈：

```objc
objc_initWeak / objc_storeWeak
  storeWeak
    weak_register_no_lock
      weak_entry_insert
```


在将要走出 w1 变量的作用域时，runtime 触发了以下调用栈：

```objc
objc_destroyWeak
  storeWeak
    weak_unregister_no_lock
      remove_referrer
```

在 obj 释放时，runtime 触发了以下调用栈：

```objc
objc_storeStrong
  objc_release
    objc_object::release
      objc_object::rootRelease()
        objc_object::rootRelease(bool, bool)
          dealloc
            _objc_rootDealloc 
              objc_object::rootDealloc
                object_dispose
                  objc_destructInstance
                    objc_object::clearDeallocating
                      objc_object::clearDeallocating_slow
                        weak_clear_no_lock
```

我们顺着这几个函数调用栈，抽取关键信息进行分析。

### 创建关联信息

```objc
id objc_initWeak(id *location, id newObj)
{
    if (!newObj) {
        *location = nil;
        return nil;
    }
    
    // <false, true, true>
    return storeWeak<DontHaveOld, DoHaveNew, DoCrashIfDeallocating>
        (location, (objc_object*)newObj);
}
id objc_storeWeak(id *location, id newObj)
{
    // <true, true, true>
    return storeWeak<DoHaveOld, DoHaveNew, DoCrashIfDeallocating>
        (location, (objc_object *)newObj);
}

```
`objc_initWeak`  只是简单地判空处理后，调用了 `storeWeak` 函数，并传入一些模版参数，这里的 location 就是 `__weak` 修饰的指针变量地址，newObj 为赋值对象的地址，`objc_storeWeak` 同理。

```objc
static id storeWeak(id *location, objc_object *newObj) {

    ...

    id oldObj;
    SideTable *oldTable;
    SideTable *newTable;
    if (haveOld) {
        // 获取老对象的地址
        oldObj = *location;
        oldTable = &SideTables()[oldObj];
    } else {
        oldTable = nil;
    }
    if (haveNew) {
        newTable = &SideTables()[newObj];
    } else {
        newTable = nil;
    }

    ...
    
    if (haveOld) {
        // __weak 修饰的指针变量已经指向过某对象
        // 需要把这个对象和此指针变量的关联断开
        // 这个函数调用在销毁关联信息一节再分析
        weak_unregister_no_lock(&oldTable->weak_table, oldObj, location);
    }
    if (haveNew) {
        // 关联新对象和 __weak 修饰的指针变量
        newObj = (objc_object *)
            weak_register_no_lock(&newTable->weak_table, (id)newObj, location, 
                                  crashIfDeallocating);
        if (newObj  &&  !newObj->isTaggedPointer()) {
            // 设置 isa 指针的 weakly_referenced 位 / sidetable 中的 SIDE_TABLE_WEAKLY_REFERENCED 位
            // 标记此对象被 __weak 修饰的指针变量指向了，dealloc 时可以加速置 nil 处理
            newObj->setWeaklyReferenced_nolock();
        }
        // 设置 __weak 修饰的指针变量的值为 newObj
        *location = (id)newObj;
    }

    return (id)newObj;
}
```

这里的 SideTable 我们可以简单地把它视为保存对象引用计数和弱引用表的结构，对于一个对象来说这个结构实例是唯一的。一般来说，objc 2.0 的对象引用计数都会优先保存在 isa 的 extra_rc 位段中，只有超出了存储的限制才会将超出部分保存到对应的 SideTable 中，isa 使用 has_sidetable_rc 标记是否超出限制。

在设置新的关联前，如果 `__weak` 修饰的指针变量已经关联了其他对象，那么此函数会先解除旧关联，再设置新的。如果 newObjc 是 nil，那么只会进行解除关联以及指针置 nil 操作，`objc_destroyWeak` 就以这种方式调用 `storeWeak` 来执行销毁动作。

```objc
id weak_register_no_lock(weak_table_t *weak_table, id referent_id, 
                      id *referrer_id, bool crashIfDeallocating)
{
    // 对象地址
    objc_object *referent = (objc_object *)referent_id;
    // __weak 修饰的变量指针地址
    objc_object **referrer = (objc_object **)referrer_id;

    if (!referent  ||  referent->isTaggedPointer()) return referent_id;
  
    // 确保对象没有在释放中
    ...

    // 添加关联信息
    weak_entry_t *entry;
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        // 将 weak 变量地址加入到 entry 中
        append_referrer(entry, referrer);
    } 
    else {
        weak_entry_t new_entry(referent, referrer);
        // 如果 weak_table 容量不够，就创建更多空间
        weak_grow_maybe(weak_table);
        // 将新的 entry 插入 weak_table 中
        weak_entry_insert(weak_table, &new_entry);
    }

    return referent_id;
}
```

这里面涉及到了两个结构 `weak_table_t` 和 `weak_entry_t`，其结构如下：

```objc
struct weak_table_t {
    weak_entry_t *weak_entries;       // 存储对象地址 和 __weak 修饰变量的 hash table
    size_t    num_entries;            // hash table 大小
    uintptr_t mask;                   // 辅助计算 hash 索引的位遮罩
    uintptr_t max_hash_displacement;  // hash 索引最大偏移量 （下文会说明用处）
};

struct weak_entry_t {
    DisguisedPtr<objc_object> referent; // 包含对象地址的结构
    union {
        struct {
            weak_referrer_t *referrers;               // DisguisedPtr 指针（DisguisedPtr 有 __weak 指针变量地址信息）
            uintptr_t        out_of_line_ness : 2;    // 是否超出默认数组长度
            uintptr_t        num_refs : PTR_MINUS_2;  // 和 referent 关联的 __weak 修饰的指针变量个数
            uintptr_t        mask;                    // 同 weak_table_t
            uintptr_t        max_hash_displacement;   // 同 weak_table_t
        };
        struct {
            // out_of_line_ness field is low bits of inline_referrers[1]
            weak_referrer_t  inline_referrers[WEAK_INLINE_COUNT]; // DisguisedPtr 定长数组（4）
        };
    };
    ...
};
```
后面会频繁提及这两个结构。

回到 `weak_register_no_lock` 函数，由于是第一次设置 `__weak` 变量，没有现成的 entry，需要新建一个，所以走的是 else 新增逻辑分支，如果是多个 `__weak` 变量指向同个对象时，entry 是可以同时保存这几个变量的地址的，这时候就是走的 `append_referrer` 分支。

```objc
static void weak_entry_insert(weak_table_t *weak_table, weak_entry_t *new_entry)
{
    weak_entry_t *weak_entries = weak_table->weak_entries;
    assert(weak_entries != nil);

    // 根据对象地址，生成 hash 值 （hash_pointer 就是哈希函数）
    // 然后将 hash 值和 mask 位遮罩做按位与操作，其值作为数组索引
    // mask 的值为 weak_table 的 size - 1 ，所以算出来的索引不会越界
    size_t begin = hash_pointer(new_entry->referent) & (weak_table->mask);
    size_t index = begin;
    size_t hash_displacement = 0;
    // index 上的值不为空的话，可以视为 hash 碰撞，继续查找后续的空值索引保存
    // max_hash_displacement 只有在有 index 重复了才会用到
    while (weak_entries[index].referent != nil) {
        // 这样写可以让 index 访问 mask 内的所有索引
        // 如 mask 为 4，begin 为 3，则最差情况下 index 的值可能为 3 4 0 1 2
        // hash_displacement 最终结果为 4
        // 后续获取时，如果 hash_displacement 超过 4，则视为访问失败
        index = (index+1) & weak_table->mask;
        if (index == begin) bad_weak_table(weak_entries);
        hash_displacement++;
    }
    // 设置新的 entry 并增加 entry 计数
    weak_entries[index] = *new_entry;
    weak_table->num_entries++;

    if (hash_displacement > weak_table->max_hash_displacement) {
        // 设置 hash 索引最大偏移量（删除时会用来判断是否超出最大偏移值）
        weak_table->max_hash_displacement = hash_displacement;
    }
}
```
可以看到，上方 `weak_table` 的 `weak_entries` 字段可视为哈希表，key 由对象地址生成，value 是记录 `__weak` 修饰变量地址的 entry 结构。 `weak_entry_for_referent` 函数从哈希表中获取 entry，和 `weak_entry_insert` 实现类似，这里不做赘述。

调用 `weak_entry_insert` 函数之后，一次弱引用记录的创建就算完成了，

### 销毁关联信息

```objc
void objc_destroyWeak(id *location)
{ 
    // <true, false, false>
    (void)storeWeak<DoHaveOld, DontHaveNew, DontCrashIfDeallocating>
        (location, nil);
}
```
`objc_destroyWeak` 传入了 nil ，用以清空 location 地址上的对象指针，并且由于没有非 nil 新值，`storeWeak` 只会删除不会新建关联信息。`storeWeak` 上一节已经分析过，这里直接看 `weak_unregister_no_lock` 函数。

```objc
void weak_unregister_no_lock(weak_table_t *weak_table, id referent_id, 
                        id *referrer_id)
{
    objc_object *referent = (objc_object *)referent_id;
    objc_object **referrer = (objc_object **)referrer_id;

    weak_entry_t *entry;

    if (!referent) return;
    // 根据对象地址获取 entry
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        // 移除 entry 中值为 referrer 的指针变量地址
        remove_referrer(entry, referrer);
        bool empty = true;
        // entry 中是否有关联的指针变量地址
        if (entry->out_of_line()  &&  entry->num_refs != 0) {
            empty = false;
        }
        else {
            for (size_t i = 0; i < WEAK_INLINE_COUNT; i++) {
                if (entry->inline_referrers[i]) {
                    empty = false; 
                    break;
                }
            }
        }

        if (empty) {
            // 如果 entry 是空的话，就从 weak_table 中移除掉
            weak_entry_remove(weak_table, entry);
        }
    }
}
```
这里将销毁的 `__weak` 变量地址从 entry 中删除。

### 指针变量置 nil


```objc
void weak_clear_no_lock(weak_table_t *weak_table, id referent_id) 
{
    objc_object *referent = (objc_object *)referent_id;
    // 根据对象地址获取 entry
    weak_entry_t *entry = weak_entry_for_referent(weak_table, referent);
    if (entry == nil) {
        return;
    }
    weak_referrer_t *referrers;
    size_t count;
    // 获取需要置 nil 的指针变量个数
    if (entry->out_of_line()) {
        referrers = entry->referrers;
        count = TABLE_SIZE(entry);
    } 
    else {
        referrers = entry->inline_referrers;
        count = WEAK_INLINE_COUNT;
    }
    
    for (size_t i = 0; i < count; ++i) {
      // 获取指针变量的地址
        objc_object **referrer = referrers[i];
        if (referrer) {
            if (*referrer == referent) {
                // 将指针变量置为 nil
                *referrer = nil;
            }
            else if (*referrer) {
                _objc_inform("__weak variable at %p holds %p instead of %p. "
                             "This is probably incorrect use of "
                             "objc_storeWeak() and objc_loadWeak(). "
                             "Break on objc_weak_error to debug.\n", 
                             referrer, (void*)*referrer, (void*)referent);
                objc_weak_error();
            }
        }
    }
    
    // 将 entry 从 weak_table 中移除
    weak_entry_remove(weak_table, entry);
}
```

刨去前面 `dealloc` 相关的调用函数，`weak_clear_no_lock` 只是根据释放对象的地址，查找关联的 entry ，遍历 entry 中的地址，置 nil 地址上的指针变量。

### weak_entry_t 的两种形式

上面分析基本围绕着 `weak_table_t` 展开，实际上它只是第一层哈希表，其存储的 `weak_entry_t` value 内部也可以实现为一个哈希表，只不过 `weak_table_t` 使用对象地址生成 hash 值，而 `weak_entry_t` 使用 `__weak` 修饰的指针变量地址生成 hash 值。

这里回到 `weak_entry_t` 的结构：

```objc

struct weak_entry_t {
    DisguisedPtr<objc_object> referent; // 包含对象地址的结构
    union {
        struct {
            weak_referrer_t *referrers;               // DisguisedPtr 指针（DisguisedPtr 有 __weak 指针变量地址信息）
            uintptr_t        out_of_line_ness : 2;    // 是否超出默认数组长度
            uintptr_t        num_refs : PTR_MINUS_2;  // 和 referent 关联的 __weak 修饰的指针变量个数
            uintptr_t        mask;                    // 同 weak_table_t
            uintptr_t        max_hash_displacement;   // 同 weak_table_t
        };
        struct {
            // out_of_line_ness field is low bits of inline_referrers[1]
            weak_referrer_t  inline_referrers[WEAK_INLINE_COUNT]; // DisguisedPtr 定长数组（4）
        };
    };
    ...
};
```
`weak_entry_t` 定义了一个 union ，其中 WEAK_INLINE_COUNT 宏为 4 ，也就是说在初始状态下，这个 union 的空间有 `weak_referrer_t inline_referrers[4]` 这么大，当 entry 保存指针变量地址的个数不大于 4 个时，我们就可以直接使用 `inline_referrers` 数组，这样写的话，访问更加快速便捷。

我们再看下关联的变量个数大于 4 的情况：

```objc
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSObject *obj = [A new];
        __unused __weak NSObject *w0 = obj;
        __unused __weak NSObject *w1 = obj;
        __unused __weak NSObject *w2 = obj;
        __unused __weak NSObject *w3 = obj;
        __unused __weak NSObject *w4 = obj;
    }
    return 0;
}
```

当 entry 已经存在时，再关联指针变量则会走 `append_referrer` 函数，也就是上方的 w1 开始到 w4 都走的 `append_referrer`。

```objc
static void append_referrer(weak_entry_t *entry, objc_object **new_referrer)
{
    // 关联变量个数是否超出 4
    if (! entry->out_of_line()) {
        for (size_t i = 0; i < WEAK_INLINE_COUNT; i++) {
            // 默认数组是否有闲余的位置存放新增加的关联数据
            if (entry->inline_referrers[i] == nil) {
                entry->inline_referrers[i] = new_referrer;
                return;
            }
        }

        // inline_referrers 数组满了，把其中的数据暂存到新申请的内存中
        // 由于 union 特性，num_refs 这些字段和 inline_referrers 数组使用的同一块内存
        // 为了后面修改 num_refs 等字段不会影响到关联数据，所以需要提前暂存
        weak_referrer_t *new_referrers = (weak_referrer_t *)
            calloc(WEAK_INLINE_COUNT, sizeof(weak_referrer_t));
        for (size_t i = 0; i < WEAK_INLINE_COUNT; i++) {
            new_referrers[i] = entry->inline_referrers[i];
        }
        entry->referrers = new_referrers;
        entry->num_refs = WEAK_INLINE_COUNT;
        // 设置超出界限标识
        entry->out_of_line_ness = REFERRERS_OUT_OF_LINE;
        // mask 为 table size - 1
        entry->mask = WEAK_INLINE_COUNT-1;
        entry->max_hash_displacement = 0;
    }

    assert(entry->out_of_line());
    // 关联数据个数是否大于 table size 的 3/4
    if (entry->num_refs >= TABLE_SIZE(entry) * 3/4) {
        // 增加 table 大小，并插入，其内部会调用 append_referrer
        return grow_refs_and_insert(entry, new_referrer);
    }
    // 这里的插入逻辑，hash 索引计算同 weak_table_t
    size_t begin = w_hash_pointer(new_referrer) & (entry->mask);
    size_t index = begin;
    size_t hash_displacement = 0;
    while (entry->referrers[index] != nil) {
        hash_displacement++;
        index = (index+1) & entry->mask;
        if (index == begin) bad_weak_table(entry);
    }
    if (hash_displacement > entry->max_hash_displacement) {
        // 设置最大 hash 偏移
        entry->max_hash_displacement = hash_displacement;
    }
    // 设置新关联信息
    weak_referrer_t &ref = entry->referrers[index];
    ref = new_referrer;
    // 设置实际保存的关联指针变量个数
    entry->num_refs++;
}
```
可以看到，w1-w3 会直接使用 `inline_referrers`，一旦设置 w4，关联数据就大于 4 了，`weak_entry_t` 将不会使用内置数组，而是使用 `grow_refs_and_insert` 函数申请新的内存。

```objc
__attribute__((noinline, used))
static void grow_refs_and_insert(weak_entry_t *entry, 
                                 objc_object **new_referrer)
{
    assert(entry->out_of_line());

    size_t old_size = TABLE_SIZE(entry);
    // 每次申请，都在原来的容量上乘 2 倍
    size_t new_size = old_size ? old_size * 2 : 8;

    size_t num_refs = entry->num_refs;
    weak_referrer_t *old_refs = entry->referrers;
    // mask 为 table size - 1
    entry->mask = new_size - 1;
    
    // 重新申请内存
    entry->referrers = (weak_referrer_t *)
        calloc(TABLE_SIZE(entry), sizeof(weak_referrer_t));
    entry->num_refs = 0;
    entry->max_hash_displacement = 0;
    // 把旧数据保存到新内存中
    for (size_t i = 0; i < old_size && num_refs > 0; i++) {
        if (old_refs[i] != nil) {
            append_referrer(entry, old_refs[i]);
            num_refs--;
        }
    }
    // 将新数据保存到新内存中
    append_referrer(entry, new_referrer);
    if (old_refs) free(old_refs);
}
```
这里调用 `append_referrer` 时，由于已经设置了 `out_of_line_ness` ，`out_of_line` 函数将会返回 true，在数据再次溢出 hash table 之前，我们可以直接走插入流程。