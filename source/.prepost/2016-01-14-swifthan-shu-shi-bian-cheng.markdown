---
layout: post
title: "Swift函数式编程"
date: 2016-01-14 17:57:04 +0800
comments: true
categories: 
---
```swift
func assertStringPairsMatchInDictionary(dictionary: NSDictionary, pairs: [(key: CFString, expectedOutput: String)]) {
    for pair in pairs {
        let a = dictionary[String(pair.0)] as! CFStringRef
        XCTAssertEqual(a as String, pair.1)
    }
}

func assertStringPairsMatchInDictionary(dictionary: NSDictionary, pairs: [(key: CFString, expectedOutput: String)]) {
	pairs.forEach { XCTAssertEqual(dictionary[String($0.0)].flatMap { $0 as? String }, $0.1) }
}
```

##参考
[Functional Programming in Swift](http://five.agency/functional-programming-in-swift/)