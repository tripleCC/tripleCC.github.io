---
layout: post
title: "CoreData后台堆栈的使用"
date: 2016-03-06 00:36:21 +0800
comments: true
categories: 
---

##参考资料
[Core Data 网络应用实例](http://objccn.io/issue-10-5/)<br>
[
Core Data Unique Constraints](http://blog.zachorr.com/post/129785280807/core-data-unique-constraints)<br>
[iCloud and Core Data](https://www.objc.io/issues/10-syncing-data/icloud-core-data/)<br>
[Common Background Practices](https://www.objc.io/issues/2-concurrency/common-background-practices/)<br>
[NSFetchedResultsController Class Reference](https://developer.apple.com/library/tvos/documentation/CoreData/Reference/NSFetchedResultsController_Class/index.html)<br>
[multi-context-coredata](https://www.cocoanetics.com/2012/07/multi-context-coredata/)<br>
[Concurrency](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/Concurrency.html#//apple_ref/doc/uid/TP40001075-CH24-SW1)<br>
[core-datas-nsprivatequeueconcurrencytype-and-sharing-objects-between-threads](http://stackoverflow.com/questions/8637921/core-datas-nsprivatequeueconcurrencytype-and-sharing-objects-between-threads)<br>
[ios-8-core-data-and-asynchronous-fetching--cms-22241](http://code.tutsplus.com/tutorials/ios-8-core-data-and-asynchronous-fetching--cms-22241)

// 讲述使用后台堆栈的几种不同方式<br>
[concurrent-core-data-stack-performance-shootout](http://floriankugler.com/2013/04/29/concurrent-core-data-stack-performance-shootout/)<br>
[backstage-with-nested-managed-object-contexts](http://floriankugler.com/2013/05/13/backstage-with-nested-managed-object-contexts/)<br>
[the-concurrent-core-data-stack](http://floriankugler.com/2013/04/02/the-concurrent-core-data-stack/)<br>
[concurrency-coredata](https://blog.codecentric.de/en/2014/11/concurrency-coredata/)