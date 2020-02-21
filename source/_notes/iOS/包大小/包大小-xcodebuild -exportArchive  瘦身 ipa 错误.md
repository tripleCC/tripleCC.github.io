错误： Exported SPWebPSizeTest to: /Users/songruiwang/Develop/SPWebPSizeTest/build-thin/Export



具体错误：/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems/core_ext/kernel_require.rb:54:in `require': cannot load such file -- sqlite3 (LoadError)

​	from /System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems/core_ext/kernel_require.rb:54:in `require'

​	from /Applications/Xcode.app/Contents/Developer/usr/bin/ipatool:28:in `<main>'



原因：

/Applications/Xcode.app/Contents/Developer/usr/bin/ipatool 

使用了system ruby

\#!/usr/bin/sandbox-exec -n no-network /usr/bin/ruby -E UTF-8 -v



外界使用了 rvm 版本ruby



尝试处理方式：

\1. #!/usr/bin/sandbox-exec -n no-network /usr/bin/ruby -E UTF-8 -v 

改为 

\#!/usr/bin/env ruby

（不好改打包机上的）



\2. ruby use system

gem install bundler --user-install

（改了之后一些依赖安装会有问题，首先应该安装 bundler ，不过 bundle install 时会报错）



最终处理方式：Note: the [[xcbuild-safe.sh script](https://github.com/fastlane/fastlane/blob/master/gym/lib/assets/wrap_xcodebuild/xcbuild-safe.sh)]([https://github.com/fastlane/fastlane/blob/master/gym/lib/assets/wrap_xcodebuild/xcbuild-safe.sh](ticktick://ttMarkdownLink)) wraps around xcodebuild to workaround some incompatibilities.



/usr/bin/xcrun path/to/xcbuild-safe.sh -exportArchive \

-exportOptionsPlist '/tmp/gym_config_1442852529.plist' \

-archivePath '/Users/fkrause/Library/Developer/Xcode/Archives/2015-09-21/App 2015-09-21 09.21.56.xcarchive' \

-exportPath '/tmp/1442852529'



gym 支持传入 export_options 瘦身



exportArchive 会根据不同的 os 版本生成不同的 ipa（所以 ipa 取决于两种情况，os 版本和设备类型）

输出的根目录的 ipa 有问题，大小不确定，可能是 Apps 下的任一个 ipa，并且没有找到可以配置的参数，导出特定 os 版本的 ipa，先通过一下脚本选取生成 ipa 中最小的：

min_ipa=`find Apps -type f -ls | sort -k7 | head -n 1 | tr ' ' '\n' | tail -1`