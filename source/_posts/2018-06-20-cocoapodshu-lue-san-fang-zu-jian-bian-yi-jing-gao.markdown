---
layout: post
title: "CocoaPods忽略三方组件编译警告"
date: 2018-06-20 21:58:25 +0800
comments: true
categories: 
---


为了减少组件化后的工程集成时间，我们一般都会将三方库放到私有 GitLab 中，这也有利于开发者根据自家业务，对三方库进行定制包装。但是如果有些三方库更新较慢，以至于让新版本的 Xcode 产生很多警告，这就比较烦了，因为大部分情况下，更改三方库并不是一个明智的选择。

Podfile 提供了 `inhibit_all_warnings!` 以屏蔽所有 pod target 的警告，但其中也包括了非三方组件。同时，Podfile 提供了 `inhibit_warnings` 去针对单个 pod 的编译警告进行控制，比如：

```ruby
pod 'SSZipArchive', :inhibit_warnings => true
```
以上代码只会屏蔽 SSZipArchive 组件的警告，这比较符合我们的诉求。不过 `inhibit_warnings` 只会禁止当前 pod 的警告，并不会一同处理依赖组件的警告，这就要求我们在 Podfile 中显式依赖所有三方组件，并且设置 `inhibit_warnings`。


<!--more-->

暂时搁置下这种体力活，我们看下有没有更好的处理方式。遇到这种问题，首先想到的是可以在 `pre_install` / `post_install` 中统一设置。在 CocoaPods 源码中搜索 `inhibit_warnings`，定位到以下代码 ：

```ruby
def add_files_to_build_phases(native_target, test_native_targets)
	...
	flags = compiler_flags_for_consumer(consumer, arc)
  regular_file_refs = project_file_references_array(files, 'source')
  native_target.add_file_references(regular_file_refs, flags)
	...
end

def compiler_flags_for_consumer(consumer, arc)
  ...
  if target.inhibit_warnings?
    flags << '-w -Xanalyzer -analyzer-disable-all-checks'
  end
  flags * ' '
  ...
end
```
可以看到，在添加文件至对应 target 时，`-w -Xanalyzer -analyzer-disable-all-checks` 同时被添加到了文件的 compiler flags （在Target -> Build Phases -> Compile Sources 中可见）。结合 Installer 的 install! 代码：

```ruby
def install!
  prepare
  resolve_dependencies
  download_dependencies
  validate_targets
  generate_pods_project
  if installation_options.integrate_targets?
    integrate_user_project
  else
    UI.section 'Skipping User Project Integration'
  end
  perform_post_install_actions
end

def download_dependencies
  UI.section 'Downloading dependencies' do
    install_pod_sources
    run_podfile_pre_install_hooks
    clean_pod_sources
  end
end
```
`generate_pods_project` 方法执行了 PodTargetInstaller 的 install! 操作，将文件添加到了 pod target ，那么只能在其之前的 `pre_install` 设置相关属性了。从上面的代码还可以看出，执行 `pre_install` 前就已经 `resolve_dependencies` 了，也就是说我们可以拿到 Analyzer 分析的完整结果 AnalysisResult :

```ruby
# @return [Hash{TargetDefinition => Array<Specification>}] the
#         specifications grouped by target.
#
attr_accessor :specs_by_target

# @return [Array<Specification>] the specifications of the resolved
#         version of Pods that should be installed.
#
attr_accessor :specifications

# @return [Array<AggregateTarget>] The aggregate targets created for each
#         {TargetDefinition} from the {Podfile}.
#
attr_accessor :targets
```

上面列出了此次需要涉及到的 AnalysisResult 属性。这里要注意的是 `targets` 属性是不包含 Pods Target 的，它只包含了 Podfile 里面声明的 target ，一般为组件本身，以及组件Tests。如果不确定要设置哪个 target ，可以手动设置 `inhibit_warnings` ，然后通过以下代码打印出 hash :

```ruby
...
pod 'SSZipArchive', :inhibit_warnings => true
...

pre_install do |installer|
	require 'pp'
  installer.analysis_result.specs_by_target.each_key do |target_definition|
  	pp target_definition.to_hash
  end
end
```
这里我们对所有涉及到的 target 都进行设置。接着看下 CocoaPods Core 代码中 Podfile 是如何设置 `inhibit_warnings` 的 : 

```ruby
def pod(name = nil, *requirements)
  ...
  current_target_definition.store_pod(name, *requirements)
end

def store_pod(name, *requirements)
	...
  parse_inhibit_warnings(name, requirements)
  ...
end

def parse_inhibit_warnings(name, requirements)
	...
  set_inhibit_warnings_for_pod(pod_name, should_inhibit)
	...
end

# Inhibits warnings for a specific pod during compilation.
def set_inhibit_warnings_for_pod(pod_name, should_inhibit)
  hash_key = case should_inhibit
             when true
               'for_pods'
             when false
               'not_for_pods'
             when nil
               return
             else
               raise ArgumentError, "Got `#{should_inhibit.inspect}`, should be a boolean"
             end
  raw_inhibit_warnings_hash[hash_key] ||= []
  raw_inhibit_warnings_hash[hash_key] << pod_name
end
```
找到了设置 inhibit_warnings 的 public 方法 `set_inhibit_warnings_for_pod`。

由于我们的三方库集中放在 cocoapods-repos 的 group 下，最终的 `pre_install` 长这样 :

```ruby
pre_install do |installer|
  installer.analysis_result.specs_by_target.each_key do |target_definition|
    installer.analysis_result.specifications.each do |spec|
      source = spec.attributes_hash['source']
      source &&= source['git']
      next unless source && source.include?('cocoapods-repos')

      targets = (Array(target_definition) + target_definition.children)
      targets.each do |target|
        target.set_inhibit_warnings_for_pod(spec.root.name, true)
      end
    end
  end
end
```

