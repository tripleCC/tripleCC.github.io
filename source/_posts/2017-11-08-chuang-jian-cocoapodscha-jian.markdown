---
layout: post
title: "编写自己的 CocoaPods 插件"
date: 2017-11-08 22:19:01 +0800
comments: true
categories: ruby 
tags: [CocoaPods,Ruby]
---


经过对旧项目持续地拆分，组件库已经初具规模，组件粒度也变得越来越小，管理组件的成本也逐渐显现出来。目前团队采用的方式是，每个组件由特定的负责人进行管理，只有责任人才拥有 master 分支的访问权限，并且打 tag、发布组件版本都需要由负责人操作。

当一个特性涉及到的组件库不多时，直接在钉钉上通知相关负责人升级下组件版本即可，然后将各个组件的新版本重新写入 Podfile。刚开始我会查下负责人是谁，然后在群组里罗列他需要升级的组件。但是修改的组件一多就比较麻烦了，如果直接把涉及的所有组件名往群组里一扔，组员有时候也会看漏了。

于是我就有了下面的想法：<br>
用脚本获取 Podfile 指向分支的组件名，然后去本地私有源获取组件的作者，再匹配本地存储的组员名，最后将负责人和所负责的组件发送到钉钉群组中。

<!--more-->

## 准备
cocoapods 有许多好用的小插件，比如 `cocoapods-open` （ 执行 `pod open` 可以直接打开 `.xcworkspace` 文件），这些插件 gem 都有特定的目录分层。刚开始以为自己要从零开始配置，后来发现 [cocoapods-plugin](https://github.com/CocoaPods/cocoapods-plugins) 本身就提供了用来创建一个模版工程的 `create` 命令。

输入以下命令即可创建一个模版工程：

```sh
// 安装
gem install cocoapods-plugins
// 创建
pod plugins create NAME [TEMPLATE_URL]
```

在这个需求中，我创建了 `author` 子命令，所以输入：

```sh
pod plugins create author
```

当前路径下会生成 `cocoapods-author` 目录，其结构如下：

```sh
.
├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── cocoapods-author.gemspec
├── lib
│   ├── cocoapods-author
│   │   ├── command
│   │   │   └── author.rb
│   │   ├── command.rb
│   │   └── gem_version.rb
│   ├── cocoapods-author.rb
│   └── cocoapods_plugin.rb
└── spec
    ├── command
    │   └── author_spec.rb
    └── spec_helper.rb
```

其中 `author.rb` 的初始内容如下（添加了点注释）：

```ruby
module Pod
  class Command
    # This is an example of a cocoapods plugin adding a top-level subcommand
    # to the 'pod' command.
    #
    # You can also create subcommands of existing or new commands. Say you
    # wanted to add a subcommand to `list` to show newly deprecated pods,
    # (e.g. `pod list deprecated`), there are a few things that would need
    # to change.
    #
    # - move this file to `lib/pod/command/list/deprecated.rb` and update
    #   the class to exist in the the Pod::Command::List namespace
    # - change this class to extend from `List` instead of `Command`. This
    #   tells the plugin system that it is a subcommand of `list`.
    # - edit `lib/cocoapods_plugins.rb` to require this file
    #
    # @todo Create a PR to add your plugin to CocoaPods/cocoapods.org
    #       in the `plugins.json` file, once your plugin is released.
    #
    class Author < Command
      # pod plugins list 时，展示的概要信息
      self.summary = 'Short description of cocoapods-author.'

      # --help / 命令错误时展示的描述信息
      self.description = <<-DESC
        Longer description of cocoapods-author.
      DESC

      # --help / 命令错误时展示的参数信息
      self.arguments = 'NAME'

      def initialize(argv)
        @name = argv.shift_argument
        super
      end

      # 校验方法（查看文件是否存在等）
      def validate!
        super
        help! 'A Pod name is required.' unless @name
      end

      # 运行命令
      def run
        UI.puts "Add your implementation for the cocoapods-author plugin in #{__FILE__}"
      end
    end
  end
end
```

注释文档说明了如何创建 `list` 的子命令 `deprecated`：

1、移动目标文件至 `lib/pod/command/list/deprecated.rb`，并且将这个子命令类放进 Pod::Command::List 命名空间中；  <br>
2、更改子命令类的父类为 `List` ； <br>
3、在 `lib/cocoapods_plugins.rb` 中载入该文件 <br>

由于我暂时不需要子命令，所以直接继承 Command 就可以了。

## 获取 Podfile untagged 组件名

```ruby
UNTAGGED_FLAGS = [:path, :git, :branch, :commit]

def load_untageed_dependencies_hash
  file_path = Dir.pwd + '/Podfile'

  raise %Q[没有找到 Podfile，请确认是否在 Podfile 所在文件夹\n] unless File.file?(file_path)

  podfile = Podfile.from_file(file_path)
  dependencies = podfile.to_hash['target_definitions'].first['dependencies']

  # UI.puts dependencies

  untageed_dependencies = dependencies.select do |dependency|
    tagged = true
    if dependency.kind_of? Hash
      first = dependency.values.first.first
      if first.kind_of? Hash 
        tagged = first.keys.reduce(true) do |result, flag|
          !UNTAGGED_FLAGS.include?(flag) & result
        end
      elsif first.kind_of? String
        tagged = true   
      end
    elsif dependency.is_a?(String)
      tagged = true 
    end
    !tagged
  end

  untageed_dependencies.reduce({}) do |result, dependency|
    result.merge(dependency)
  end
end
```

以上方法返回没有依赖 tag 的组件哈希。这里我为了简单处理，直接获取 `target_definitions` 第一个元素的 `dependencies` 作为工程的依赖进行遍历。


## 获取本地私有源获取组件的作者
获取本地私有源的组件作者：

```ruby
def load_pod_authors(spec_files)
  author_hash = {}  
  spec_files.each do |file|
    if !file.nil? && File.file?(file)
      podspec = Specification.from_file(file)   
      pod_authors = podspec.attributes_hash['authors']

      if pod_authors.kind_of? Hash
        author = pod_authors.keys.first
      elsif pod_authors.kind_of? Array
        author = pod_authors.first
      else
        author = pod_authors
      end
      author = author.downcase

      if !author.nil? && !podspec.name.nil?
        author_hash[author] =  author_hash[author].nil? ? [] : author_hash[author]
        author_hash[author].append(podspec.name)
      end
    end
  end
  author_hash
end
```

获取组员信息：

```ruby
def load_boss_keeper_members
  member_hash = {}
  @memebrs_hash.uniq.map.each do |nickname| 

    reform_memeber_hash_proc = -> nickname, realname do
      nickname = nickname.downcase unless !nickname.nil?
      pinyin = Pinyin.t(nickname, splitter: '').downcase
      if pinyin != nickname 
        member_hash[nickname] = realname
      end

      member_hash[pinyin] = realname
    end

    if nickname.kind_of? Hash
      name = nickname.keys.first.dup.force_encoding("UTF-8")
      nickname.values.first.append(name).each do |nickname|
        reform_memeber_hash_proc.call(nickname, name)
      enddef load_pod_authors(spec_files)
  author_hash = {}  
  spec_files.each do |file|
    if !file.nil? && File.file?(file)
      podspec = Specification.from_file(file)   
      pod_authors = podspec.attributes_hash['authors']

      if pod_authors.kind_of? Hash
        author = pod_authors.keys.first
      elsif pod_authors.kind_of? Array
        author = pod_authors.first
      else
        author = pod_authors
      end
      author = author.downcase

      if !author.nil? && !podspec.name.nil?
        author_hash[author] =  author_hash[author].nil? ? [] : author_hash[author]
        author_hash[author].append(podspec.name)
      end
    end
  end
  author_hash
end
    else
      reform_memeber_hash_proc.call(nickname, nickname)
    end
  end
  member_hash
end
```
在钉钉上 `@` 组员 需要手机号码，这一部分数据都从本地的 yaml 文件读取：

```ruby
file_path = File.join(File.dirname(__FILE__),"boss_keeper_members.yaml")
yaml_hash =     
begin
  YAML.load_file(file_path)
rescue Psych::SyntaxError, Errno::EACCES, Errno::ENOENT
  {}
end

@memebrs_hash = yaml_hash['members']
@mobiles = yaml_hash["mobiles"].reduce({}){ |result, mobile| result.merge(mobile) }
```

由于作者一栏存在用花名、原名、昵称的情况，所以 yaml 文件基本格式如下：

```
members:
- 青木:
  - tripleCC

mobiles:
- 青木:
  - 1xxxxxxx
```

## 匹配本地存储的组员名
首先匹配是组内组员管理的组件，如果是其他组创建的组件，暂时忽略：
```
def load_valid_pod_authors_hash
  authors_hash = {}
  @pod_authors.each do |name, pods|
    member_name = @boss_keeper_members[name.downcase]
    if !member_name.nil?
      member_name = member_name.downcase
      author_pods = authors_hash[member_name].nil? ? [] : authors_hash[member_name]
      authors_hash[member_name] = author_pods.append(pods).flatten
    end
  end
  authors_hash
end
```

然后将结果和未指定 tag 的组件哈希匹配：
```
def load_untageed_dependencies_authors_hash
  authors_hash = {}
  valid_pod_authors = load_valid_pod_authors_hash
  untageed_dependencies_hash = load_untageed_dependencies_hash
  untageed_dependencies_hash.keys.each do |pod|
    valid_pod_authors.each do  |author, pods|
      if pods.include?(pod)
        authors_hash[author] = authors_hash[author].nil? ? [] : authors_hash[author]
        authors_hash[author].append(pod)
      end
    end
  end
  authors_hash
end
```

## 整合发送至钉钉

通过 `git rev-parse --abbrev-ref HEAD` 获取当前所在分支，然后根据作者、组件名、手机号码创建 curl 命令并执行：
```ruby
def post_message_to_ding_talk
  current_branch = `git rev-parse --abbrev-ref HEAD`.strip

  untageed_dependencies_authors_hash = load_untageed_dependencies_authors_hash
  untageed_dependencies_authors_hash.each do |author, pods|
    content = author + "，#{current_branch}分支" + "，下面的仓库打个版本：" + pods.join('，')
    if !@mobiles[author].nil?
      mobile = @mobiles[author].first
    end

    curl = %Q[
    curl 'https://oapi.dingtalk.com/robot/send?access_token=xxxxxxx' \
       -H 'Content-Type: application/json' \
       -d '
      {
        "msgtype": "text", 
        "text": {
            "content": "#{content}"
         },
         "at": {
            "atMobiles": [
              "#{mobile}"
            ], 
            "isAtAll": false
        }
      }']
      # UI.puts curl
    Kernel.system curl
  end
end
```

## 总结
后续如果对这个插件进行扩展的话，应该会考虑根据私有源自动生成 Podfile ，解决封版时，需要手动修改 Podfile 的情况，麻烦而且可能存在把版本号写错的情况。

最后， ruby 的语法还需要多熟悉熟悉，虽然这个插件能用，但是看起来代码质量还是渣。
## 参考

[cocoapods-plugins](https://github.com/CocoaPods/cocoapods-plugins)