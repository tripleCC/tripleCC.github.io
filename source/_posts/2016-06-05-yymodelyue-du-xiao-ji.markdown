---
layout: post
title: "YYModel阅读小记"
date: 2016-06-05 22:22:15 +0800
comments: true
categories: 
---
YYModel是由ibireme开发的一套小而精美的模型转换框架，采用分类的形式，无需继承框架的某个基类就可以方便地完成模型的转换，且内部做了自动类型转换和安全处理，可以有效地防止因模型类型和后台给的数据类型不一样而产生的崩溃问题。<br>
近些天抽空拜读了一下其源码，果然是思维严谨，考虑的一些细节也很到位，让人自叹弗如。虽然作者说这个框架是花了两个周末的时间完成的，但是其代码质量还是非常让人惊艳的，值得仔细阅读。

<!--more-->

#### 基本结构
YYModel总共由5个文件组成，其中核心文件只有以下四个：

```objc
YYClassInfo.h
YYClassInfo.m
NSObject+YYModel.h
NSObject+YYModel.m
```
`YYClassInfo`主要将成员变量、方法、成员属性以及类这四类信息，从C层面的函数调用抽象成OC的类。这个文件主要的类有以下四个：

```objc
YYClassInfo 			// 类
YYClassPropertyInfo		// 成员属性	
YYClassMethodInfo		// 方法	
YYClassIvarInfo			// 成员变量
```
`YYClassInfo`包含三个以后三者的`name`为键，以后三者为值的字典。由于YYModel使用遍历属性的方式来达到模型转换的目的，所以其中的`propertyInfos`起比较重要的作用。

该文件还包含一个枚举类型：`YYEncodingType`，列举了各类编码信息，包括值类型、方法限定类型、属性修饰类型。`YYEncodingType`使用掩码的方式对这三类不同的枚举信息进行分类，各占据1个字节：

```objc
YYEncodingTypeMask      		    = 0xFF		//值类型
YYEncodingTypeQualifierMask   	  = 0xFF00		//方法限定类型
YYEncodingTypePropertyMask      = 0xFF0000		//属性修饰类型
```
其中`YYEncodingTypeQualifierMask`和`YYEncodingTypePropertyMask`可以进行逻辑与操作，来表示被多个修饰符修饰或限定的属性或方法。<br>
详细的编码信息可以从以下链接获取：<br>
[Declared Properties](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html)<br>
[Type Encodings](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html)<br>

### 核心代码
模型转换的核心功能无非两种：model->json、json->model，所以这里主要纪录下框架中这两个主要功能的阅读笔记。

#### json->model
`yy_modelWithJSON`是json转模型的入口，可以先从这个方法入手。

 ```objc
 + (instancetype)yy_modelWithJSON:(id)json {
    NSDictionary *dic = [self _yy_dictionaryWithJSON:json];
    return [self yy_modelWithDictionary:dic];
}
 ```
 以上代码通过`_yy_dictionaryWithJSON`将json转换成了字典，再调用`yy_modelWithDictionary`对字典进行转换，事实上，真正的对外转换方法应该是`yy_modelWithDictionary`，所有对集合内部模型的转换，最终都使用了这个方法。<br>
 这里有一个小技巧，就是对方法的命名，对内方法/函数添加'_'前缀，对外去处此前缀，这种做法在CoreFoundation里面也比较常见。

```objc
+ (instancetype)yy_modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:cls];
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one yy_modelSetWithDictionary:dictionary]) return one;
    return nil;
}
```
获取字典之后，就可以生成调用实例所属类信息了。这里关于类`_YYModelMeta`作者注释的已经非常详细了:

```objc
@interface _YYModelMeta : NSObject {
    @package  // 表示在同一个包内可见，这个倒是比较少用
    YYClassInfo *_classInfo;
    /// Key:mapped key and key path, Value:_YYModelPropertyMeta.
    NSDictionary *_mapper;
    /// Array<_YYModelPropertyMeta>, all property meta of this model.
    NSArray *_allPropertyMetas;
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// Array<_YYModelPropertyMeta>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    YYEncodingNSType _nsType;
    
    // 这几个布尔用来纪录用户是否实现了对应的自定义方法
    BOOL _hasCustomWillTransformFromDictionary;
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end
```
`_mapper`为所有映射信息，以key为键(最原始的)，以`_YYModelPropertyMeta`实例为值;要注意的是这里的key还没有被拆分成keyPath数组，还是原始的形式:@"key1.key2"，而且在属性映射到一个数组时，这里的key便是一个数组<br>
`_allPropertyMetas`为当前模型所有属性的信息<br>
`_keyPathPropertyMetas`为映射到keyPath属性的信息<br>
`_multiKeysPropertyMetas`为映射到一个数组的属性信息<br>
`_YYModelMeta`只存储到属性`_YYModelPropertyMeta`层面的信息，更加细化的信息，比如拆分成数组的keyPath，属性映射到的数组等信息，都是交由`_YYModelPropertyMeta`进行存储，`_YYModelMeta`存储的只是最原始的key信息。<br>
关于`_YYModelPropertyMeta`：

```objc
@interface _YYModelPropertyMeta : NSObject {
    @package
    NSString *_name;             ///< property's name
    YYEncodingType _type;        ///< property's type
    YYEncodingNSType _nsType;    ///< property's Foundation type
    BOOL _isCNumber;             ///< is c number type
    Class _cls;                  ///< property's class, or nil
    Class _genericCls;           ///< container's generic class, or nil if threr's no generic class
    SEL _getter;                 ///< getter, or nil if the instances cannot respond
    SEL _setter;                 ///< setter, or nil if the instances cannot respond
    BOOL _isKVCCompatible;       ///< YES if it can access with key-value coding
    BOOL _isStructAvailableForKeyedArchiver; ///< YES if the struct can encoded with keyed archiver/unarchiver
    BOOL _hasCustomClassFromDictionary; ///< class/generic class implements +modelCustomClassForDictionary:
    
    /*
     property->key:       _mappedToKey:key     _mappedToKeyPath:nil            _mappedToKeyArray:nil
     property->keyPath:   _mappedToKey:keyPath _mappedToKeyPath:keyPath(array) _mappedToKeyArray:nil
     property->keys:      _mappedToKey:keys[0] _mappedToKeyPath:nil/keyPath    _mappedToKeyArray:keys(array)
     */
    NSString *_mappedToKey;      ///< the key mapped to
    NSArray *_mappedToKeyPath;   ///< the key path mapped to (nil if the name is not key path)
    NSArray *_mappedToKeyArray;  ///< the key(NSString) or keyPath(NSArray) array (nil if not mapped to multiple keys)
    YYClassPropertyInfo *_info;  ///< property's info
    _YYModelPropertyMeta *_next; ///< next meta if there are multiple properties mapped to the same key.
}
@end
```
`_mappedToKey`映射到的key(@{property : key})<br>
`_mappedToKeyPath`映射到的keyPath(@{property : key1.key2})<br>
`_mappedToKeyArray`映射到的数组(@{property : @[key1, key2]})<br>
每个`_YYModelPropertyMeta`中，这三者只有其中一个会有值。有了这三个属性，就可以获取需要转化的对应字典的value了。<br>
这里记录下`_YYModelMeta`的init方法执行流程:

```
1、根据Class获取YYClassInfo实例
2、获取需要被忽略的属性（用户提供）
3、获取白名单（除了白名单，其它属性都被忽略，用户提供）
4、获取类型为集合的属性中存储的类类型（用户提供）
5、循环获取所有的属性信息，并生成`_YYModelPropertyMeta`实例，存储至allPropertyMetas、keyPathPropertyMetas、multiKeysPropertyMetas
6、设置属性映射关系_mapper（用户提供）
7、设置属性映射关系_mapper（原生属性，非用户自定义映射）
8、设置用户是否实现转换相关自定义方法布尔属性
```
一些基本的信息类设置完成后，就开始设置实例的属性了：

```objc
// 设置前对传入的字典进行更改
if (modelMeta->_hasCustomWillTransformFromDictionary) {
    dic = [((id<YYModel>)self) modelCustomWillTransformFromDictionary:dic];
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
}

// 集合上下文
ModelSetContext context = {0};
context.modelMeta = (__bridge void *)(modelMeta);
context.model = (__bridge void *)(self);
context.dictionary = (__bridge void *)(dic);

if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
    CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
    if (modelMeta->_keyPathPropertyMetas) {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                             CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    if (modelMeta->_multiKeysPropertyMetas) {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                             CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
} else {
    CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                         CFRangeMake(0, modelMeta->_keyMappedCount),
                         ModelSetWithPropertyMetaArrayFunction,
                         &context);
}
// 设置后对实例的属性进行更改
if (modelMeta->_hasCustomTransformFromDictionary) {
    return [((id<YYModel>)self) modelCustomTransformFromDictionary:dic];
}
```
当`modelMeta->_keyMappedCount`大于等于`CFDictionaryGetCount((CFDictionaryRef)dic)`时，
执行以下步骤：

```
1、遍历字典，并以字典为基准，设置模型中与字典相对应的属性
2、通过_keyPathPropertyMetas，设置映射到keyPath的属性
3、通过_multiKeysPropertyMetas，设置映射到数组的属性
```
否则直接通过`_allPropertyMetas`设置所有属性。<br>
字典回调函数的如下：

```objc
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _YYModelMeta *meta = (__bridge _YYModelMeta *)(context->modelMeta);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        // 映射到同个key之后，这里循环赋给属性相同的值
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}
```
在遍历字典时，回调函数会根据字典的key从`_mapper`中获取对应的`_YYModelPropertyMeta`，
然后通过`ModelSetValueForProperty`设置属性值。如果`propertyMeta`的`_next`不为空，即表示有多个属性被映射到了同一个key。<br>
这样做的好处是只需要从字典中取一次value，就可以设置被映射到同一个key的所有属性；而通过`_allPropertyMetas`设置时，则需要对每个属性
都对字典做一次取值操作。作者在[优化Tip](http://blog.ibireme.com/2015/10/23/ios_model_framework_benchmark/)的第8点中也提到：

```
8. 减少遍历的循环次数
在 JSON 和 Model 转换前，Model 的属性个数和 JSON 的属性个数都是已知的，这时选择数量较少的那一方进行遍历，会节省很多时间。
```
数组的回调函数如下：

```objc
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = (__bridge _YYModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
    	// 映射到多个key
        value = YYValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
    	// 映射到keyPath
        value = YYValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
    	// 映射到一个key
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}
```
其中`YYValueForMultiKeys`代码如下:

```objc
static force_inline id YYValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        // 只要对上了dic中的一个key，就退出
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        } else {
            // key不是NSString，为NSArray，使用keyPath取值
            value = YYValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}
```
在一个属性被映射到多个key时，只取第一个匹配成功的key，后续的key将会被略过。
`YYValueForKeyPath`的代码如下：

```objc
static force_inline id YYValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    
    return value;
}
```
作者为了优化代码性能，将映射的`keyPath`以`.`为分隔符拆分成多个字符串，并以数组的形式存储，最终用循环获取`value`的方式代替`valueForKeyPath:`，也解决了从非字典取`value`时的崩溃问题。当然在不考虑性能的情况下，也可以用以下方式实现:

```objc
NSString *keyPath = [keyPaths componentsJoinedByString:@"."];
@try {
	value = [dic valueForKeyPath:keyPath];
} @catch (NSException *exception) { }
```
YYModel采用`objc_msgSend`直接调用`Getter/Setter`，替代了使用KVC对属性进行取值/设置。作者的优化Tip3就说明了避免 KVC:

```
3. 避免 KVC
Key-Value Coding 使用起来非常方便，但性能上要差于直接调用 Getter/Setter，所以如果能避免 KVC 而用 Getter/Setter 代替，性能会有较大提升。
```
设置属性值通过方法`ModelSetValueForProperty`实现。首先，函数把属性分为了三类类型进行处理：

```
C数值类型
NS系统自带基本类类型
非常规类型
```
其中`C数值类型`判断如下：

```objc
static force_inline BOOL YYEncodingTypeIsCNumber(YYEncodingType type) {
    switch (type & YYEncodingTypeMask) {
        case YYEncodingTypeBool:
        case YYEncodingTypeInt8:
        case YYEncodingTypeUInt8:
        case YYEncodingTypeInt16:
        case YYEncodingTypeUInt16:
        case YYEncodingTypeInt32:
        case YYEncodingTypeUInt32:
        case YYEncodingTypeInt64:
        case YYEncodingTypeUInt64:
        case YYEncodingTypeFloat:
        case YYEncodingTypeDouble:
        case YYEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}

```
`NS系统自带类类型`判断如下：

```objc
static force_inline YYEncodingNSType YYClassGetNSType(Class cls) {
    if (!cls) return YYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return YYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return YYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return YYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return YYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return YYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return YYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return YYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return YYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return YYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return YYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return YYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return YYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return YYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return YYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return YYEncodingTypeNSSet;
    return YYEncodingTypeNSUnknown;
}
```
需要注意的是`mutable`类型一般都继承于`immutable`类型，所以需要先判断是否为`mutable`。由于类簇的原因，我们是无法在`runtime`时获取属性是否是`mutable`的，所以只能进行静态判断，这也是`_YYModelPropertyMeta`的`_nsType`存在的意义。(PS: 在函数`ModelSetValueForProperty`中，关于类簇的问题似乎还没有从YYModel主线合入到YYKit的YYModel中。YYKit的YYModel版本，使用了`isKindOfClass`来分区分`NSMutableString`和`NSString`，导致属性类型是`NSMutableString`的情况下，获得的还是`immutable`版本)<br>
更多关于类簇的资料可以参考:[从NSArray看类簇](http://blog.sunnyxx.com/2014/12/18/class-cluster/)、[ClassClusters](https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html)。<br>

当属性为集合类型时，赋值稍微要麻烦些。比如针对`YYEncodingTypeNSArray`，有如下处理代码:

```objc
if (meta->_genericCls) {
    NSArray *valueArr = nil;
    if ([value isKindOfClass:[NSArray class]]) valueArr = value;
    else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
    if (valueArr) {
        NSMutableArray *objectArr = [NSMutableArray new];
        for (id one in valueArr) {
            // 已经是所要对象了
            if ([one isKindOfClass:meta->_genericCls]) {
                [objectArr addObject:one];
            } else if ([one isKindOfClass:[NSDictionary class]]) {
                // 给的是字典，要自己构造
                Class cls = meta->_genericCls;
                if (meta->_hasCustomClassFromDictionary) {
                    // 由字典返回对应的类(透传) <<< 由开发者实现
                    cls = [cls modelCustomClassForDictionary:one];
                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                }
                NSObject *newOne = [cls new];
                // 根据获得的类，创建实例
                [newOne yy_modelSetWithDictionary:one];
                if (newOne) [objectArr addObject:newOne];
            }
        }
        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
    }
} else {
    if ([value isKindOfClass:[NSArray class]]) {
        if (meta->_nsType == YYEncodingTypeNSArray) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
        } else {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                           meta->_setter,
                                                           ((NSArray *)value).mutableCopy);
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        if (meta->_nsType == YYEncodingTypeNSArray) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSSet *)value).allObjects);
        } else {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                           meta->_setter,
                                                           ((NSSet *)value).allObjects.mutableCopy);
        }
    }
}
```
在使用者没有通过`modelContainerPropertyGenericClass`或者和[类型同名的`protocols`](https://github.com/ibireme/YYModel/issues/79)指定集合中元素的类型时，`_genericCls`是为nil的，所以如果`value`是NSArray或者NSSet类型，那么YYModel将`value`直接赋给属性，并没有做多余的解析。<br>
在使用者已经指定了集合中元素类型的情况下，第一个分支就会对每个元素进行解析并构造成相应的实例。如果集合元素依然是一个字典，那么就会调用`yy_modelSetWithDictionary`嵌套解析。
<br>
YYModel给使用者提供了极强的扩展性。在解析的过程中，使用者可以根据在`modelCustomClassForDictionary:`方法中传入的字典，决定想要生成实例的类型。

#### model->json
model->json的入口方法为`yy_modelToJSONObject` ：

```objc
- (id)yy_modelToJSONObject {
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
     */
    id jsonObject = ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}
```
主要是利用`ModelToJSONObjectRecursive`对model进行嵌套包装，最终生成只包含`NSArray/NSDictionary/NSString/NSNumber/NSNull`的JSON对象。`ModelToJSONObjectRecursive`的执行逻辑如下:

```
1、如果是基本类型:kCFNull、NSString、NSNumber或者nil，直接返回
2、如果是NSDictionary，能JSON化就直接返回，否则调用ModelToJSONObjectRecursive嵌套解析，最后添加到字典中
3、如果是NSSet、NSArray，并且元素是基本类型就直接添加到数组中，否则调用ModelToJSONObjectRecursive嵌套解析成基本类型，然后添加到数组中
4、如果是NSURL、NSAttributedString、NSDate类型，转成字符串返回。是NSData就返回nil
5、剩下的基本就是自定义的类了，需要遍历对应的_mapper进行处理
```
第五步遍历_mapper的代码主要由两部分组成：1、获取属性值；2、构造字典<br>
获取属性值的代码如下：

```objc
if (!propertyMeta->_getter) return;

id value = nil;
// 这里是获取属性对应的值(转化成NSString或者NSNumber的)
if (propertyMeta->_isCNumber) {
    value = ModelCreateNumberFromProperty(model, propertyMeta);
} else if (propertyMeta->_nsType) {
    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
    value = ModelToJSONObjectRecursive(v);
} else {
    switch (propertyMeta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeObject: {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            // 属性是自定义的对象，嵌套解析
            value = ModelToJSONObjectRecursive(v);
            if (value == (id)kCFNull) value = nil;
        } break;
        case YYEncodingTypeClass: {
            Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = v ? NSStringFromClass(v) : nil;
        } break;
        case YYEncodingTypeSEL: {
            SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = v ? NSStringFromSelector(v) : nil;
        } break;
        default: break;
    }
}
if (!value) return;
```
总体来说和`ModelSetValueForProperty`的处理较为类似，也是分的三种大类。<br>
构造字典的代码如下：

```objc
// 这里是根据map构造字典
if (propertyMeta->_mappedToKeyPath) {
    NSMutableDictionary *superDic = dic;
    NSMutableDictionary *subDic = nil;
    for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
        NSString *key = propertyMeta->_mappedToKeyPath[i];
        if (i + 1 == max) { // end  { ext = { d = Apple; }; }, 最后的key才赋值, 即superDic[@"d"] = @"Apple"
            if (!superDic[key]) superDic[key] = value;
            break;
        }
        
        subDic = superDic[key];
        if (subDic) {
            // 说明这一层字典已经有键值对了
            if ([subDic isKindOfClass:[NSDictionary class]]) {
                // 拷贝成可变的（没这一句也可，因为刚开始时创建的都是NSMutableDictionary), 方便i + 1 == max时进行赋值
                subDic = subDic.mutableCopy;
                superDic[key] = subDic;
            } else {
                break;
            }
        } else {
            // key下没有value，创建可变字典赋给当前的key
            subDic = [NSMutableDictionary new];
            superDic[key] = subDic;
        }
        // 最顶层的字典(@{@"a" : @{@"b" : @"c"}}，即字典@{@"b" : @"c"})
        superDic = subDic;
        subDic = nil;
    }
} else {
    if (!dic[propertyMeta->_mappedToKey]) {
        dic[propertyMeta->_mappedToKey] = value;
    }
}
```
### 小结
很粗略地记录下部分阅读过程。YYModel有不少值得学习的地方，不管是代码风格还是考虑问题的全面性，这些都需要通过阅读源码来了解。