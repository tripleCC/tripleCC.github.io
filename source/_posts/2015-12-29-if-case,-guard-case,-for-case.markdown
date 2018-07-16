---
layout: post
title: "Swift2.0中的case匹配"
date: 2015-12-29 17:15:29 +0800
comments: true
categories: swift
---
Swift在2.0版本之后，对if、guard、for的匹配进行了一定的加强，其中case匹配模式感觉还是挺新奇的。

参照Swift官方手册，可以知道，这种模式在针对可选值进行处理时，可以获得额外的便利：

```swift
let someOptional: Int? = 42
// Match using an enumeration case pattern
if case .Some(let x) = someOptional {
    print(x)
}
 
// Match using an optional pattern
if case let x? = someOptional {
    print(x)
}
```
x?是.Some(let x)的简写方式。单从以上代码段，可能还看不出有什么特别之处，相反还比以前的实现繁琐：

```swift
if let x = someOptional {
    print(x)
}
```
不过官方手册体现其便利的是for关键字，if还需要另一种场景来体现其带来的便利：

```swift
let arrayOfOptionalInts: [Int?] = [nil, 2, 3, nil, 5]
// Match only non-nil values
for case let number? in arrayOfOptionalInts {
    print("Found a \(number)")
}

// 输出
// Found a 2
// Found a 3
// Found a 5
```
可以看到，在遍历可选值数组的场景下，这种方式确实减少了一些代码，要是以前，我可能会这样实现：

<!--more-->

```swift
// 1
for x in arrayOfOptionalInts {
    if let x = x {
        print(x)
    }
}

// 2
arrayOfOptionalInts.flatMap{$0}.map{ print($0) }
```

Kingfisher、Alarmfire以及Swift开源Foundation的NSSet类中，都使用到了这个特性：

```swift
// Kingfisher
if let transitionItem = optionsInfo?.kf_firstMatchIgnoringAssociatedValue(.Transition(.None)),
    case .Transition(let transition) = transitionItem where cacheType == .None {
        
        UIView.transitionWithView(sSelf, duration: 0.0, options: [],
            animations: {
                indicator?.stopAnimating()
            },
            completion: { finished in
                UIView.transitionWithView(sSelf, duration: transition.duration,
                    options: transition.animationOptions,
                    animations: {
                        transition.animations?(sSelf, image)
                    },
                    completion: { finished in
                        transition.completion?(finished)
                        completionHandler?(image: image, error: error, cacheType: cacheType, imageURL: imageURL)
                    }
                )
            }
        )
} else {
    indicator?.stopAnimating()
    sSelf.image = image
    completionHandler?(image: image, error: error, cacheType: cacheType, imageURL: imageURL)
}


// Alarmfire
public enum ValidationResult {
    case Success
    case Failure(NSError)
}
public func validate(validation: Validation) -> Self {
    delegate.queue.addOperationWithBlock {
        if let
            response = self.response where self.delegate.error == nil,
            case let .Failure(error) = validation(self.request, response)
        {
            self.delegate.error = error
        }
    }

    return self
}

// NSSet 
public func isSubsetOfSet(otherSet: Set<NSObject>) -> Bool {
    for case let obj as NSObject in allObjects where !otherSet.contains(obj) {
        return false
    }
    return true
}
```
按照我的思路编写的话，在老版本中，我会这样实现后面两个方法：

```swift
// Alarmfire
public func wvalidate(validation: Validation) -> Self {
    delegate.queue.addOperationWithBlock {
        if let response = self.response where self.delegate.error == nil {
            switch validation(self.request, response) {
            case let .Failure(error):
                self.delegate.error = error
            default :
                break
            }
        }
    }
    return self
}

// NSSet
public func isSubsetOfSet(otherSet: Set<NSObject>) -> Bool {
    for obj in allObjects where !otherSet.contains(obj) {
        if let obj = obj as? NSObject {
            return false
        }
    }
    return true
}
```
在第一个实现中，我不得不添加了default分支，即使在这个分支里面不进行任何操作，从而可见case匹配模式可以在这类场景下简化switch语句（如果只需要确认enum中的一个类型，就可以选择性地用if-case替换switch）。<br>
在第二个实现中，因为编译器的原因，我不得不将一般转换as改成可选转换as?，然后增加if语句进行判断。(针对类型转换，if-case可以缩减代码量)<br>


case匹配模式在针对`值绑定`，`元组`，`类型转换`都带来了一定便利，[Match Me if you can: Swift Pattern Matching in Detail.](http://appventure.me/2015/08/20/swift-pattern-matching-in-detail/#sec-9)这篇文章中，对这几种情况进行了非常详细的讲解，并列举了一些实际应用的例子，推荐阅读。