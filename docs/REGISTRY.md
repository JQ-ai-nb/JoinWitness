# Mooncakes 实际发布与独立消费记录

日期：2026-10-20。此记录只有公开包信息，不包含登录 code、token 或凭据。

## 发布

项目使用隔离 Moon home，未改动机器上其他用户的 Mooncakes 凭据。

```text
moon whoami
Logged in as JQ-ai-nb

moon publish
Check passed
running moon check on extracted package
Check passed
Server status: 200 OK
```

- 包：`JQ-ai-nb/joinwitness@0.1.0`，MIT，`yanked=false`。
- registry 创建时间：`2026-10-20T02:38:47.358573+00:00`。
- registry 源码提交：`ebfc5ca07f8f0e96d5da30703df1b3ac6e9cd638`。
- 服务器下载归档：195432 字节。
- SHA256：`4491d1ca1d13a1bf2f79b2b55d44074c29853a9e2cbe43241bbc564e31071263`。

发布归档、全新消费项目下载的归档、registry index 声明的 checksum 三者一致。它与 GitHub 源码加预编译演示 ZIP 是不同归档，不能混用校验值。

## 全新消费

新建空目录和空 `MOON_HOME`；开始时没有 `.mooncakes` 缓存，也没有 `credentials.json`。使用同一兼容工具链，但不复用项目依赖、凭据或本地路径引用。

`moon.mod` 初始内容：

```text
name = "local/joinwitness_registry_probe"
version = "0.1.0"
preferred_target = "wasm-gc"
```

`moon.pkg`：

```text
import {
  "JQ-ai-nb/joinwitness" @join,
}

pkgtype(kind: "executable")
```

将 [typed demo](../cmd/demo/main.mbt) 内容复制到该空项目的 `main.mbt`，运行：

```sh
moon add JQ-ai-nb/joinwitness@0.1.0
moon check --deny-warn
moon run . --target wasm-gc
moon run . --target js
```

实际安装输出包括 `Registry index cloned successfully`、`Downloading JQ-ai-nb/joinwitness@0.1.0`；生成模块的 import 为 registry 版本依赖，没有 path override。check 成功，两次运行均输出：

```text
baseline pairs=4; candidate=2
retained=2, lost=2, gained=0
counterexample rows=3; independently verified=true
safe materialized pairs=2
```

`audit.mbt` 下载内容与发布源码一致，SHA256 为 `9deeaa5091c248ac7b22a4e1f2d22aed73d0f858b92d38e1a613e57294efdfb0`。此检查验证实际 registry 安装与 API 使用；完整边界和语义测试仍以仓库测试及多平台 CI 为准。

0.1.0 归档内文档是不可变的发布前快照，因此保留“待发布”旧说明。当前主分支与 GitHub Release 说明记录本次已完成状态；业务源码没有因这次状态更新改变。
