echo "Hello, I'm tripleCC!"
cd /Users/songruiwang/GitHubIO/octopress
rake new_post[$1]
cd ./source/_posts

file=`find . -atime -1s`
echo $file
open $file 
