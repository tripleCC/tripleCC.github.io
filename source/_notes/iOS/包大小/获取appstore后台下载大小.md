fastlane 对应的类 https://github.com/fastlane/fastlane/blob/master/spaceship/docs/AppStoreConnect.md#login



appstore connect API：

https://developer.apple.com/documentation/appstoreconnectapi





获取大小还是需要用 https://appstoreconnect.apple.com/WebObjects/iTunesConnect.woa/ 接口，appstore connect API 貌似只能获取一些基本信息。



require "spaceship"



Spaceship::Tunes.login('[triplec.linux@gmail.com](http://triplec.linux@gmail.com)')

Spaceship::Tunes.select_team(team_id: '118051760')



app = Spaceship::Tunes::Application.find(1064034435)



获取所有版本

train_numbers = app.all_build_train_numbers



可以选择拿前 4 个版本号（或者全拿）

train_numbers = train_numbers.sort.reverse.take(4)



所有版本号对应的所有 build 

tune_builds = train_numbers.map { |n| app.tunes_all_builds_for_train(train: n) }.flatten



通过 sizes_in_bytes 拿到

puts tune_builds.map(&:details)