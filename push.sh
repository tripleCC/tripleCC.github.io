echo "Hello, I'm tripleCC!"
cd /Users/songruiwang/GitHubIO/octopress
rake generate
rake deploy

git add .
git commit -m "update blog"
git push origin source
