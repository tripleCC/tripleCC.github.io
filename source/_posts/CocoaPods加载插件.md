---
title: CocoaPods 如何加载插件
date: 2018-12-29 14:40:46
tags:
---

CocoaPods 为开发者提供了插件注册功能，可以使用 `pod plugins create NAME` 命令创建插件，并在 Podfile 中通过 `plugin 'NAME'` 语句引入插件。虽然在一般情况下很少使用这个功能，但在某些场景下，利用插件能比较方便快捷地解决问题，比如[清除 `input`，`output` 文件](https://github.com/tripleCC/cocoapods-input-output-cleaner)、[创建 Podfile DSL](https://github.com/tripleCC/cocoapods-tdfire-binary) 等。

<!--more-->
刚开始写 CocoaPods 插件时，对其怎么执行没有 `require` 的插件代码比较好奇，但限于对 ruby 以及 gem 知识的了解，也就没有进一步地探索其实现原理，毕竟首要任务是解决工作问题。如今回过头来看这个问题，发现实现起来还是比较简单的。来看下 CocoaPods 是如何实现的。

## 实现探索

首先，由于 `pod install` 过程会涉及到插件的加载，所以直接查看 `installer.rb` 文件:

```ruby
# Runs the registered callbacks for the plugins post install hooks.
#
def run_plugins_post_install_hooks
  context = PostInstallHooksContext.generate(sandbox, aggregate_targets)
  HooksManager.run(:post_install, context, plugins)
end

# Runs the registered callbacks for the plugins pre install hooks.
#
# @return [void]
#
def run_plugins_pre_install_hooks
  context = PreInstallHooksContext.generate(sandbox, podfile, lockfile)
  HooksManager.run(:pre_install, context, plugins)
end

# Ensures that all plugins specified in the {#podfile} are loaded.
#
# @return [void]
#
def ensure_plugins_are_installed!
  require 'claide/command/plugin_manager'

  loaded_plugins = Command::PluginManager.specifications.map(&:name)

  podfile.plugins.keys.each do |plugin|
    unless loaded_plugins.include? plugin
      raise Informative, "Your Podfile requires that the plugin `#{plugin}` be installed. Please install it and try installation again."
    end
  end
end
```

其中 `run_plugins_pre_install_hooks` 和 `run_plugins_post_install_hooks` 分别执行了插件注册的 `pre_install` 和 `pod_install` 方法， `ensure_plugins_are_installed` 则确认插件是否已被安装。

接下来看下 `Command::PluginManager` ，这个类在 `claide/command/plugin_manager` 文件内，属于 `claide` gem :

```ruby
# @return [Array<Gem::Specification>] Loads plugins via RubyGems looking
#         for files named after the `PLUGIN_PREFIX_plugin` and returns the
#         specifications of the gems loaded successfully.
#         Plugins are required safely.
#
def self.load_plugins(plugin_prefix)
  loaded_plugins[plugin_prefix] ||=
    plugin_gems_for_prefix(plugin_prefix).map do |spec, paths|
      spec if safe_activate_and_require(spec, paths)
    end.compact
end

# @group Helper Methods

# @return [Array<[Gem::Specification, Array<String>]>]
#         Returns an array of tuples containing the specifications and
#         plugin files to require for a given plugin prefix.
#
def self.plugin_gems_for_prefix(prefix)
  glob = "#{prefix}_plugin#{Gem.suffix_pattern}"
  Gem::Specification.latest_specs(true).map do |spec|
    matches = spec.matches_for_glob(glob)
    [spec, matches] unless matches.empty?
  end.compact
end

# Activates the given spec and requires the given paths.
# If any exception occurs it is caught and an
# informative message is printed.
#
# @param  [Gem::Specification] spec
#         The spec to be activated.
#
# @param  [String] paths
#         The paths to require.
#
# @return [Bool] Whether activation and requiring succeeded.
#
def self.safe_activate_and_require(spec, paths)
  spec.activate
  paths.each { |path| require(path) }
  true
rescue Exception => exception # rubocop:disable RescueException
  message = "\n---------------------------------------------"
  message << "\nError loading the plugin `#{spec.full_name}`.\n"
  message << "\n#{exception.class} - #{exception.message}"
  message << "\n#{exception.backtrace.join("\n")}"
  message << "\n---------------------------------------------\n"
  warn message.ansi.yellow
  false
end
```

以上代码调用几个的 `Gem::Specification` 方法如下：

```ruby
# 获取最新 spec 集合
# Return the latest specs, optionally including prerelease specs if prerelease is true.
latest_specs(prerelease = false) 

# 获取 gem 中匹配的文件路径
# Return all files in this gem that match for glob.
matches_for_glob(glob) 

# 激活 spec，注册并将其 lib 路径添加到 $LOAD_PATH （$LOAD_PATH 环境变量存储 require 文件时查找的路径）
# Activate this spec, registering it as a loaded spec and adding it's lib paths to $LOAD_PATH. Returns true if the spec was activated, false if it was previously activated. Freaks out if there are conflicts upon activation.
activate() 
```

可以看到在 `loaded_plugins[plugin_prefix]` 为空的情况下，程序会执行 `plugin_gems_for_prefix` 方法，`plugin_gems_for_prefix` 方法通过 `latest_specs` 获取了最新的 spec ，并通过 spec 的 `matches_for_glob` 方法对文件进行匹配，当 spec 中存在匹配 `"#{prefix}_plugin#{Gem.suffix_pattern}"` 格式的文件时，则视其为 CocoaPods 插件。在拿到插件及其匹配文件后，`safe_activate_and_require` 方法将文件加入 $LOAD_PATH 中并 require 之。

另外 `CLAide::Command` 类会在 `run` 类方法中加载所有插件，然后根据解析后的信息，执行对应的命令:

```ruby
# @param  [Array, ARGV] argv
#         A list of (remaining) parameters.
#
# @return [Command] An instance of the command class that was matched by
#         going through the arguments in the parameters and drilling down
#         command classes.
#
def self.run(argv = [])
  plugin_prefixes.each do |plugin_prefix|
    PluginManager.load_plugins(plugin_prefix)
  end

  argv = ARGV.coerce(argv)
  command = parse(argv)
  ANSI.disabled = !command.ansi_output?
  unless command.handle_root_options(argv)
    command.validate!
    command.run
  end
rescue Object => exception
  handle_exception(command, exception)
end
```

对于通过 `pod plugin create` 命令创建的插件来说，lib 目录下都会自动生成一个 `cocoapods_plugin.rb` 文件，这个文件就是用来标识此 gem 为 CocoaPods 插件的。如果想手动创建 CocoaPods 插件，需要满足以下两个条件：
```ruby
# Handles plugin related logic logic for the `Command` class.
#
# Plugins are loaded the first time a command run and are identified by the
# prefix specified in the command class. Plugins must adopt the following
# conventions:
#
# - Support being loaded by a file located under the
# `lib/#{plugin_prefix}_plugin` relative path.
# - Be stored in a folder named after the plugin.

# - 支持通过 `lib/#{plugin_prefix}_plugin` 路径的文件加载
#   (也就是说，如果要对外暴露插件内部存的方法，需要在此文件中 require 之，比如自定义的 Podfile DSL 文件)
# - 保存在以插件命名的文件夹中
```

在 CocoaPods 上下文中，以上的 `plugin_prefix` 如下：
```ruby
self.plugin_prefixes = %w(claide cocoapods)
```


## 小结

如果需要外部 gem 以插件的形式提供某些功能，可以通过和 CocoaPods 一样的方式实现，即规定特定的命名规则，然后通过 `Gem::Specification` 提供的方法获取满足条件的 gem ，再 require 入口文件:

```
spec = Gem::Specification.find_by_name('naruto')
spec.activate
matches = spec.matches_for_glob('naruto')
matches.each do |path|
  require(path)
end
```