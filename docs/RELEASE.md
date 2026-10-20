# 0.1.0 交付与发布状态

记录日期：2026-10-20。

公开仓库：[JQ-ai-nb/JoinWitness](https://github.com/JQ-ai-nb/JoinWitness)，实际默认分支 main。在线工作台：[JoinWitness](https://jq-ai-nb.github.io/JoinWitness/)。最新自动验证与部署以 [Actions](https://github.com/JQ-ai-nb/JoinWitness/actions) 为准。

GitHub 登录、仓库所有者、模块命名空间均核对为 JQ-ai-nb；提交作者和提交者均为蒋琦及该账户的专属 GitHub noreply 邮箱。完整历史身份检查在本地和 CI 运行，不只依赖全局 Git 设置。

[已通过的三平台四目标 CI](https://github.com/JQ-ai-nb/JoinWitness/actions/runs/39354229909) 对应源码提交 `3aef2c6669182ee37ac58ca5b0f73b7f95d78740`，包括 check/test/build、35 项 MoonBit 测试、12 项 Node 集成、320 组 SQLite 完整行对对照、完整历史身份检查、格式／接口／打包及 Linux Chromium 检查。Windows 的中文日志编码问题已经修复，并有受限代码页下的回归测试。

[Pages 部署](https://github.com/JQ-ai-nb/JoinWitness/actions/runs/39354230067) 成功，真实公开页面的完整 Chromium 功能检查通过。当前网络中有 GitHub Pages 节点访问波动；公开检查使用正常 TLS 并指定可用的 GitHub Pages 节点 185.199.108.153，未关闭证书验证。遇到访问延迟可先使用归档的本地演示入口。

包已能从源码正常编译、运行和打包。`docs/ACCEPTANCE.md` 列出证据与边界。

**Mooncakes 已实际发布并完成独立安装验证。** 2026-10-20，在项目隔离 Moon home 中由 `moon whoami` 核实 `Logged in as JQ-ai-nb`，随后 `moon publish` 返回 `Server status: 200 OK`。registry 记录的创建时间为 `2026-10-20T02:38:47.358573+00:00`，模块为 `JQ-ai-nb/joinwitness@0.1.0`，未撤回。

在另一个全新目录、空 Moon home、无登录凭据和无旧依赖缓存的消费项目中，`moon add JQ-ai-nb/joinwitness@0.1.0` 实际下载服务器归档；`moon check --deny-warn` 与 wasm-gc、JavaScript 两次示例运行均通过。反例复核为 true，安全构造产生 2 对。归档 SHA256 与 registry index 一致；详见 [REGISTRY.md](REGISTRY.md)。

registry 0.1.0 来源是 `ebfc5ca07f8f0e96d5da30703df1b3ac6e9cd638`。该不可变快照的文档保留发布前状态；本次提交只更新发布证据和使用说明，业务源码未变。GitHub Release 演示归档包含本次更新后的文档，并在 BUILD_INFO.json 单独记录演示源码提交和 registry 源码提交。

官方报名、本人独立撰写的申报书、诚信确认和最终验收均不由这个技术记录替代。
