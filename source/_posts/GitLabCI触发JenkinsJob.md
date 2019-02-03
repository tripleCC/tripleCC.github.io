---
title: Git Commit 触发 Jenkins Job
date: 2018-11-19 14:40:46
tags: [GitLab, Jenkins, Ruby]
---


火展柜团队目前使用 Jenkins 做持续集成，在提测 / 预发阶段，开发人员需要频繁地在 Jenkins 平台上进行如下操作以构建测试包：

1. **在团队的 View 下创建 Job** ，一般以某个已存在 Job 为模版，这个模版已经设置好打包仓库 url 和常用配置
2. **更改需要打包的代码分支**
3. **更改钉钉 token**，构建结束后，需要将结果发送至测试钉钉群组
4. **点击构建项目**

在创建 Job 后，后续构建则只需要以下两步：

1. **更新 Podfile.lock 并提交至远程仓库**
2. **点击构建项目**



<!--more-->

## 效率提升

虽然只有两步，但切至网页操作还是挺烦的，于是就催生了 [**fire-jenkins-builder**](https://github.com/tripleCC/fire-jenkins-builder) 。

有了 [**fire-jenkins-builder**](https://github.com/tripleCC/fire-jenkins-builder) 并结合简单的配置，开发者提交如下 commit 便会触发 Jenkins 打包：

```
git commit -m "[jb] XXXXXX"
```

当然，特殊情况下也可以使用命令触发 Job ：

```
jb -p PATH -b BRANCH -l LOG_LEVEL
```

- **PATH** 为配置文件路径，关于配置文件，下文会进行说明
- **BRANCH** 为分支名称，也可在配置文件中设置
- **LOG_LEVEL** 为日志等级，默认输出等级为 Info

## 配置详情

添加 `.fire-jenkins.yml` 配置文件至目标工程根目录下：

```
# jenkins job 配置文件
# 可以通过在 commit 中添加 prefix ，使 CI 触发 jenkins job 的创建/构建行为
# 提交 commit 信息
# [jb] XXXXXX 执行 jenkins job ，如果不存在 job ，则会在对应 job_view 下创建并执行
#
########################
#         选填
########################
# job 参数
# 添加自己的钉钉消息等健值对
# 需要注意的是，这里面的配置，模版必须已经存在了，这里只是修改对应的值
parameters:
  REPORTER_ACCESS_TOKEN: XXXXXX
  DEBUG: true

########################
#         必填
########################
# 打包 job 名称 / 前缀名
# 如果 job_name 为空，则采用 job_name_prefix + 分支名称
# job_name: XXXX
job_name_prefix: ZGiOS_
# jenkins 上的分组，对应 view
job_view: 掌柜iOS

# branch 可以从 CI 变量中拿到，不需要设置
# branch: feature/jenkins-executer

# 下面配置可选
# 如果没有设置，则采用模版值
# remote_url: git@git.2dfire-inc.com:ios/restapp.git
# credentials_id: xxx

# jenkins 用户名密码
username: qingmu
password: xxx

# 各业务线采用不同的模版，配置这里
# 模版工程名称（需要唯一）
template_job_name: ZGiOS_develop

# 这里不动
server_url: 'http://jenkins-shopkeeper-client.2dfire.net'
server_port: 80
```

然后针对自己所在业务线进行定制，同业务线开发人员后续只需要更改 `job_name` 和 ` parameters` 即可，比如根据项目群组设置钉钉 token。

配置 `.gitlab-ci.yml` :

```
stages:
...
  - build
...

...
jenkins_build:
  before_script:
    - gem install fire-jenkins-builder -v 0.1.3 --no-ri --no-rdoc --conservative
  stage: build
  only:
    variables:
      - $CI_COMMIT_MESSAGE =~ /^\[jb\]/
  script: 
    - jb -p .fire-jenkins.yml -b $CI_COMMIT_REF_NAME
  tags:
    - iOSCI
  allow_failure: true
...
```

配置之后，只要 commit 信息满足 `/^\[jb\]/` [正则](https://docs.gitlab.com/ee/ci/variables/#variables-expressions)，就会触发 [GitLab CI](https://docs.gitlab.com/ee/ci/) ，[GitLab Runner](https://docs.gitlab.com/runner/index.html#gitlab-runner) 就会执行  `jb -p .fire-jenkins.yml -b $CI_COMMIT_REF_NAME`  触发 Jenkins 构建 Job ，其中 [CI_COMMIT_REF_NAME](https://docs.gitlab.com/ee/ci/variables/#priority-of-variables) 为分支名称。

## 实现细节

commit 触发 GitLab CI 部分如上节所示 ，这里主要讲下 [**fire-jenkins-builder**](https://github.com/tripleCC/fire-jenkins-builder)  的内部实现。

 [**fire-jenkins-builder**](https://github.com/tripleCC/fire-jenkins-builder)  实现代码很少，主要依赖了两个 gem：

- **jenkins_api_client** ,  提供 [Jenkins Api](https://wiki.jenkins.io/display/JENKINS/Remote+access+API) 封装
- **nokogiri** ，提供 XML 解析更改

先来看下 `build` 代码：

```ruby
def build
  jobs = client.job.list(job_name)
  if jobs.empty?
    create
  else
    job_name = client.job.chain(jobs, 'success', ['all'])[0]
    client.job.build(job_name, config['parameters'])
  end
end

def create
  client.job.create_or_update(job_name, target_xml)
  client.view.add_job(config['job_view'], job_name)
  build
end
```

首先 `build` 方法会根据 `job_name` 去查询 Jenkins 上是否已存在同名 Job ，不存在就去创建并且添加到业务线配置的 `job_view `，否则就以 `parameters` 为参数去构建 Job  ，这里的参数对应 Jenkins 配置页面中的[ **参数化构建过程** ](https://wiki.jenkins.io/display/JENKINS/Parameterized+Build)。

其中 `create_or_update` 方法第二个入参为 XML 配置数据， `target_xml` 方法如下：

```ruby
def target_xml
  job_config = client.job.get_config(config['template_job_name'])		
  parameters = config['parameters'] || []

  doc = Nokogiri::XML(job_config)
  properties = doc.search('//parameterDefinitions')
  properties.children.each do |child|
    next if child.children.empty?

    children = child.children.reject { |c| c.name.nil? }
    matched = false
    defaultValue = nil
    children.each do |c|
      if c.name == 'name' && parameters.keys.include?(c.content)
    	matched = true 
        defaultValue = parameters[c.content]
      end

      c.content = defaultValue if matched && c.name == 'defaultValue'
    end
  end

  branch_spec_node = doc.search("//hudson.plugins.git.BranchSpec")
  branch_node = branch_spec_node.children.find { |c| c.name == 'name' }
  branch_node.content = config['branch']

  if config['remote_url']
    user_remote_config_node = doc.search("//hudson.plugins.git.UserRemoteConfig")
    url_node = user_remote_config_node.children.find { |c| c.name == 'url' }
    url_node.content = config['remote_url']
  end

  if config['credentials_id']
    credentials_id_node = user_remote_config_node.children.find { |c| c.name == 'credentialsId' }
    credentials_id_node.content = config['credentials_id']
  end

  doc.to_xml
end
```

`target_xml` 先获取 `template_job_name` 模版 Job 的配置 XML ，然后根据开发者传入的 `parameters` 修改 XML 中对应节点的数据 (分支和仓库地址配置功能都由插件提供)，生成一份新的 XML 供 `create_or_update` 创建 Job。 

以上代码再结合 GitLab CI ，就可以愉快地构建 Jenkins Job 了。

