---
layout: post
title: "常用Runtime函数"
date: 2015-07-12 11:28:20 +0800
comments: true
categories: runtime
---
这里主要纪录一些常用的函数：
<!--more-->

## 类

```objc
// 根据类，获取类名
const char *class_getName(Class cls)

// 根据类名获取类
Class objc_getClass(const char *name)
```
  - 注意，以下有获取`列表`的函数需要手动`free`获取的列表
  - 成员变量

```objc
    // 获取成员变量列表
    Ivar * class_copyIvarList ( Class cls, unsigned int *outCount )
    // 获取类成员变量的信息
    Ivar class_getClassVariable ( Class cls, const char *name )
    // 根据实例变量名，获取类中实例变量
    Ivar class_getInstanceVariable ( Class cls, const char *name )
    // 往运行时创建的类添加成员变量
    BOOL class_addIvar ( Class cls, const char *name, size_t size, uint8_t alignment, const char *types )
```
  - 属性

```objc
    // 获取属性列表
    objc_property_t * class_copyPropertyList ( Class cls, unsigned int *outCount )
    // 获取指定的属性
    objc_property_t class_getProperty ( Class cls, const char *name )
    // 获取属性列表
    objc_property_t * class_copyPropertyList ( Class cls, unsigned int *outCount )
    // 为类添加属性
    BOOL class_addProperty ( Class cls, const char *name, const objc_property_attribute_t *attributes, unsigned int attributeCount )
```
  - 方法

```objc
    // 获取方法列表
    Method * class_copyMethodList ( Class cls, unsigned int *outCount )
    // 添加方法
    BOOL class_addMethod ( Class cls, SEL name, IMP imp, const char *types )
    // 获取实例方法
    Method class_getInstanceMethod ( Class cls, SEL name )
    // 获取类方法
    Method class_getClassMethod ( Class cls, SEL name )
    // 替代方法的实现
    IMP class_replaceMethod ( Class cls, SEL name, IMP imp, const char *types )
    // 返回方法的具体实现
    IMP class_getMethodImplementation ( Class cls, SEL name )
    IMP class_getMethodImplementation_stret ( Class cls, SEL name )
    // 类实例是否响应指定的selector
    BOOL class_respondsToSelector ( Class cls, SEL sel )
```
  - 协议

```objc
    // 获取协议列表
    Protocol * class_copyProtocolList ( Class cls, unsigned int *outCount )
    // 添加协议
    BOOL class_addProtocol ( Class cls, Protocol *protocol )
    // 返回类是否实现指定的协议
    BOOL class_conformsToProtocol ( Class cls, Protocol *protocol )

```

## 动态创建
  - 类

```objc
    // 创建一个新类和元类
    Class objc_allocateClassPair ( Class superclass, const char *name, size_t extraBytes );

    // 销毁一个类及其相关联的类
    void objc_disposeClassPair ( Class cls );

    // 在应用中注册由objc_allocateClassPair创建的类
    void objc_registerClassPair ( Class cls );
```
  - 对象

```objc
  // 创建类实例
  id class_createInstance ( Class cls, size_t extraBytes );

  // 在指定位置创建类实例
  id objc_constructInstance ( Class cls, void *bytes );

  // 销毁类实例
  void * objc_destructInstance ( id obj );
```

## 实例对象操作

```
// 返回指定对象的一份拷贝
id object_copy ( id obj, size_t size );

// 释放指定对象占用的内存
id object_dispose ( id obj );

// 修改类实例的实例变量的值
Ivar object_setInstanceVariable ( id obj, const char *name, void *value );

// 获取对象实例变量的值
Ivar object_getInstanceVariable ( id obj, const char *name, void **outValue );

// 返回指向给定对象分配的任何额外字节的指针
void * object_getIndexedIvars ( id obj );

// 返回对象中实例变量的值
id object_getIvar ( id obj, Ivar ivar );

// 设置对象中实例变量的值
void object_setIvar ( id obj, Ivar ivar, id value );

// 返回给定对象的类名
const char * object_getClassName ( id obj );

// 返回对象的类
Class object_getClass ( id obj );

// 设置对象的类
Class object_setClass ( id obj, Class cls );
```
## 获取类定义

```objc
// 获取已注册的类定义的列表
int objc_getClassList ( Class *buffer, int bufferCount );

// 创建并返回一个指向所有已注册类的指针列表
Class * objc_copyClassList ( unsigned int *outCount );

// 返回指定类的类定义
Class objc_lookUpClass ( const char *name );
Class objc_getClass ( const char *name );
Class objc_getRequiredClass ( const char *name );

// 返回指定类的元类
Class objc_getMetaClass ( const char *name );
```

## 成员变量、属性

```objc
// 获取成员变量名
const char * ivar_getName ( Ivar v );

// 获取成员变量类型编码
const char * ivar_getTypeEncoding ( Ivar v );

// 获取成员变量的偏移量
ptrdiff_t ivar_getOffset ( Ivar v );

// 设置关联对象
void objc_setAssociatedObject ( id object, const void *key, id value, objc_AssociationPolicy policy );

// 获取关联对象
id objc_getAssociatedObject ( id object, const void *key );

// 移除关联对象
void objc_removeAssociatedObjects ( id object );

// 获取属性名
const char * property_getName ( objc_property_t property );

// 获取属性特性描述字符串
const char * property_getAttributes ( objc_property_t property );

// 获取属性中指定的特性
char * property_copyAttributeValue ( objc_property_t property, const char *attributeName );

// 获取属性的特性列表
objc_property_attribute_t * property_copyAttributeList ( objc_property_t property, unsigned int *outCount );
```

## 方法

```objc
// 调用指定方法的实现
id method_invoke ( id receiver, Method m, ... );

// 调用返回一个数据结构的方法的实现
void method_invoke_stret ( id receiver, Method m, ... );

// 获取方法名
SEL method_getName ( Method m );

// 返回方法的实现
IMP method_getImplementation ( Method m );

// 获取描述方法参数和返回值类型的字符串
const char * method_getTypeEncoding ( Method m );

// 获取方法的返回值类型的字符串
char * method_copyReturnType ( Method m );

// 获取方法的指定位置参数的类型字符串
char * method_copyArgumentType ( Method m, unsigned int index );

// 通过引用返回方法的返回值类型字符串
void method_getReturnType ( Method m, char *dst, size_t dst_len );

// 返回方法的参数的个数
unsigned int method_getNumberOfArguments ( Method m );

// 通过引用返回方法指定位置参数的类型字符串
void method_getArgumentType ( Method m, unsigned int index, char *dst, size_t dst_len );

// 返回指定方法的方法描述结构体
struct objc_method_description * method_getDescription ( Method m );

// 设置方法的实现
IMP method_setImplementation ( Method m, IMP imp );

// 交换两个方法的实现
void method_exchangeImplementations ( Method m1, Method m2 );
```

## 方法选择器

```objc
// 返回给定选择器指定的方法的名称
const char * sel_getName ( SEL sel );

// 在Objective-C Runtime系统中注册一个方法，将方法名映射到一个选择器，并返回这个选择器
SEL sel_registerName ( const char *str );

// 在Objective-C Runtime系统中注册一个方法
SEL sel_getUid ( const char *str );

// 比较两个选择器
BOOL sel_isEqual ( SEL lhs, SEL rhs );
```

## 库相关

```objc
// 获取所有加载的Objective-C框架和动态库的名称
const char ** objc_copyImageNames ( unsigned int *outCount );

// 获取指定类所在动态库
const char * class_getImageName ( Class cls );

// 获取指定库或框架中所有类的类名
const char ** objc_copyClassNamesForImage ( const char *image, unsigned int *outCount );
```
