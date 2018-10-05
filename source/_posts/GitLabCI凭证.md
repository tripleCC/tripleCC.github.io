---
title: GitLab CI 与 Jenkins 凭证
tags:
  - GitLab
  - CI
comments: true
categories: GitLab
date: 2018-07-19 10:21:09
---


最近组内在打包时，`bundle exec pod install` 命令频繁出现 clone 组件授权失败的情况:

```
remote: HTTP Basic: Access denied
fatal: Authentication failed for 'http://xxxxxx'
```

开始以为 GitLab 的 ssh 服务不稳定，毕竟以前也出过类似的问题，但经过后续排查，发现是 GitLab CI 和 Jenkins 的 Git 凭证冲突了。

<!--more-->


clone 失败的组件都为 http 协议，通过此协议去拉代码，需要预置用户名与密码。我们在配置 jenkins slave 时，已经通过在 `.gitconfig` 文件中指定 store 缓存模式以及 `.git-credentials` 路径处理了用户名密码问题（详情可查看 [Git 工具 - 凭证存储](https://git-scm.com/book/zh/v2/Git-%E5%B7%A5%E5%85%B7-%E5%87%AD%E8%AF%81%E5%AD%98%E5%82%A8) 一节）：


```
> .gitconfig

[credential]
        helper = store --file $HOME/.git-credentials
        helper = store

> .git-credentials

http://slave:password@git.2dfire-inc.com
```

由于 Mac mini 机器资源少，我们不得不在每台 Mac mini 上同时配置 GitLab Runner 和 jenkins slave 。通过 [New CI job permissions model](https://docs.gitlab.com/ee/user/project/new_ci_build_permissions_model.html) 以及 [Cross-project permissions for CI tokens](https://gitlab.com/gitlab-org/gitlab-ce/issues/18994)，可以知道， GitLab 会创建一个 gitlab-ci-token 用户供 GitLab Runner 使用，问题恰恰就出现在这里。先看下运行 GitLab CI 任务后的 `.git-credentials` :

```
> .git-credentials

http://gitlab-ci-token:LyZVytacohmGRYVKooAo@git.2dfire-inc.com
http://slave:password@git.2dfire-inc.com
```

可以看到 GitLab Runner 插入了一条 host 与 jenkins slave 配置相同的凭证信息 `http://gitlab-ci-token:LyZVytacohmGRYVKooAo@git.2dfire-inc.com`，并且 `gitlab-ci-token` 的密码会在每次任务构建时更新。我们看下 store 缓存模式下，Git 如何读取凭证信息：

```objc
> https://github.com/git/git/blob/master/credential-store.c

#define for_each_string_list_item(item,list)            \
	for (item = (list)->items;                      \
	     item && item < (list)->items + (list)->nr; \
	     ++item)

static void lookup_credential(const struct string_list *fns, struct credential *c)
{
	struct string_list_item *fn;

	for_each_string_list_item(fn, fns)
		if (parse_credential_file(fn->string, c, print_entry, NULL))
			return; /* Found credential */
}
```
也就是说， Git 会返回第一个与 `http://git.2dfire-inc.com` 匹配的凭证。在上文环境中，返回的是 `gitlab-ci-token:LyZVytacohmGRYVKooAo`。由于这个账户密码**只是 GitLab 为了让 Runner 能在执行任务时，对构建仓库有 Git 操作权限，在完成任务后即无效**，导致 jenkins slave 使用此账户密码 clone 组件后，出现 Authentication failed 错误。

因为 Runner 每次执行任务都会在 `.git-credentials` 首行生成 `gitlab-ci-token` 凭证，所以即使手动把 `gitlab-ci-token` 凭证移动到最后一行，也是没用的。

最终的解决方法就是在 `.gitconfig` 添加[凭证匹配限制](https://git-scm.com/docs/gitcredentials) ，让内部 GitLab http 的 clone 请求都走 jenkins slave 用户：

```
> .gitconfig

[credential]
        helper = store --file $HOME/.git-credentials
        helper = store

[credential "http://git.2dfire-inc.com"]
        username = slave
```


