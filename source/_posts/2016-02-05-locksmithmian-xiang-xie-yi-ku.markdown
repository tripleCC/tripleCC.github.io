---
layout: post
title: "关于keychain封装库Locksmith"
date: 2016-02-05 14:57:48 +0800
comments: true
categories: swift
tags: [Swift,Locksmith]
---
Locksmith是一个面向协议编程的keychain封装库，也是我见过的对面向协议贯彻最彻底的一个第三方库。<br>

## Locksmith基本实现
iOS系统中有5种keychain类型：generic passwords, internet passwords, certificates, keys,以及 identities。并且针对每个类型都有4种操作：create, read, update,以及 delete。<br>

对于以上复杂的逻辑关系，Cocoa采用了一系列字符串常量以及对应的key/value进行操作。只是对于Swift来说，这种方式过于冗余而且难以记忆，并没有充分利用到其语言特性。<br>

Locksmith作者采用了protocol来解决原生方案过于复杂的问题。就像乐高玩具一样，可以随意组装不同的组件来达到不同的视觉效果，Locksmith可以让使用者遵守特定的protocol来获取对应的功能，比如需要delete功能，那么就遵循DeleteableSecureStorable协议；需要read功能，那么就遵守ReadableSecureStorable协议。而在对应的模型中，不需要额外添加函数，协议内部通过extension已经实现了对应的功能函数。开发者直接调用deleteFromKeychain或者readFromKeychain即可实现想要的功能。
<!--more-->
并且，Locksmith还通过protocol提供了更加友好的Result类型。通过遵守GenericPasswordSecureStorable或者InternetPasswordSecureStorable，就可以
读取不同的结果类型GenericPasswordResult或者InternetPasswordResult，而后面这两个结构体又分别遵守了GenericPasswordSecureStorableResultType和InternetPasswordSecureStorableResultType协议，这两个协议又针对结构体中的结果分别进行了以下处理：

```swift
// InternetPasswordSecureStorableResultType
public protocol InternetPasswordSecureStorableResultType: AccountBasedSecureStorableResultType, DescribableSecureStorableResultType, CommentableSecureStorableResultType, CreatorDesignatableSecureStorableResultType, TypeDesignatableSecureStorableResultType, IsInvisibleAssignableSecureStorableResultType, IsNegativeAssignableSecureStorableResultType {}

public extension InternetPasswordSecureStorableResultType {
    private func stringFromResultDictionary(key: CFString) -> String? {
        return resultDictionary[String(key)] as? String
    }
    
    var server: String {
        return stringFromResultDictionary(kSecAttrServer)!
    }
    
    var port: Int {
        return resultDictionary[String(kSecAttrPort)] as! Int
    }
    
    var internetProtocol: LocksmithInternetProtocol {
        return LocksmithInternetProtocol(rawValue: stringFromResultDictionary(kSecAttrProtocol)!)!
    }
    
    var authenticationType: LocksmithInternetAuthenticationType {
        return LocksmithInternetAuthenticationType(rawValue:  stringFromResultDictionary(kSecAttrAuthenticationType)!)!
    }
    
    var securityDomain: String? {
        return stringFromResultDictionary(kSecAttrSecurityDomain)
    }
    
    var path: String? {
        return stringFromResultDictionary(kSecAttrPath)
    }
}

// GenericPasswordSecureStorableResultType
public protocol GenericPasswordSecureStorableResultType: GenericPasswordSecureStorable, SecureStorableResultType, AccountBasedSecureStorableResultType, DescribableSecureStorableResultType, CommentableSecureStorableResultType, CreatorDesignatableSecureStorableResultType, LabellableSecureStorableResultType, TypeDesignatableSecureStorableResultType, IsInvisibleAssignableSecureStorableResultType, IsNegativeAssignableSecureStorableResultType {}

public extension GenericPasswordSecureStorableResultType {
    var service: String {
        return resultDictionary[String(kSecAttrService)] as! String
    }
    
    var generic: NSData? {
        return resultDictionary[String(kSecAttrGeneric)] as? NSData
    }
}
```
可以看到，最终的版本的协议遵守了很多组件协议。从上面代码块中，初步可见protocol extension的强大之处了。不过还没完，最后还要通过extension的where子句，完成读取结果的统一接口：

```swift
public extension ReadableSecureStorable where Self : GenericPasswordSecureStorable {
    func readFromSecureStore() -> GenericPasswordSecureStorableResultType? {
        do {
            if let result = try performSecureStorageAction(performReadRequestClosure, secureStoragePropertyDictionary: asReadableSecureStoragePropertyDictionary) {
                return GenericPasswordResult(resultDictionary: result)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}

public extension ReadableSecureStorable where Self : InternetPasswordSecureStorable {
    func readFromSecureStore() -> InternetPasswordSecureStorableResultType? {
        do {
            if let result = try performSecureStorageAction(performReadRequestClosure, secureStoragePropertyDictionary: asReadableSecureStoragePropertyDictionary) {
                return InternetPasswordResult(resultDictionary: result)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
```
通过以上实现方式，开发者最终面向的就是协议，不管是返回的查询结果还是遵循的增删改查组件协议。而结构体在这个框架中基本起数据中转作用，比如以下结构体：

```swift
// 网络结果
struct InternetPasswordResult: InternetPasswordSecureStorableResultType {
    var resultDictionary: [String: AnyObject]
}

// 通用结果
struct GenericPasswordResult: GenericPasswordSecureStorableResultType {
    var resultDictionary: [String: AnyObject]
}
```
上面两个结构体给ReadableSecureStorable的readFromSecureStore做读取数据的存储中转，最终我们想要的数据还是需要分别到InternetPasswordSecureStorableResultType或者GenericPasswordSecureStorableResultType对应的属性中获取。<br>

Locksmith中大量应用了protocol的extension特性，暂且不论其做法是否真的可取，但也算是面向协议编程强大之处的一种体现。

## 参考文章
[protocol-oriented-programming-in-the-real-world](http://matthewpalmer.net/blog/2015/08/30/protocol-oriented-programming-in-the-real-world/)<br>
为现有类型添加新功能/解藕以增加灵活性与可测试性/方便同步快速发展的API/更少的代码更多的功能<br>
[Locksmith源码－有更详细的使用说明](https://github.com/matthewpalmer/Locksmith)

## 一些其它关于面向协议编程应用文章
[Protocol-Oriented Programming in Swift 2](http://code.tutsplus.com/tutorials/protocol-oriented-programming-in-swift-2--cms-24979)<br> 
解决多继承/协议扩展/Classes的重要性<br>
[iOS 9 Tutorial Series: Protocol-Oriented Programming with UIKit](http://www.captechconsulting.com/blogs/ios-9-tutorial-series-protocol-oriented-programming-with-uikit)<br> 
现有文章示例代码大多为人为创造的情景下工作/面向协议真对UIKit 的应用/Swift协议的好处与限制/不能给Objective-C协议中的方法提供默认实现/可以给Objective-C协议添加新方法/协议for模型,数据格式,UI风格/协议及其扩展适合在添加共享、范性功能时使用，并不很切合UI<br>
[Improved Protocol-Oriented Programming with Untyped Type Aliases](http://www.capitalone.io/blog/improved-protocol-oriented-programming-untyped-type-aliases/)<br>