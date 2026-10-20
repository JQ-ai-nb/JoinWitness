# 技术自检 — 2026-10-20

源码、示例、证据复核、本地检查、JQ-ai-nb 本人授权的 Mooncakes 发布和独立安装验证均已完成。软件发布待办已补齐；本人申报材料、正式报名和官方验收仍须本人处理，助手自检不等于官方验收。

| 检查 | 证据／状态 |
| --- | --- |
| GitHub 账户 | API `/user` 已核实 JQ-ai-nb，ID 314918884；公开仓库 owner 相同 |
| 提交一致性 | 所有保留提交作者和提交者统一为蒋琦；邮箱 314918884+JQ-ai-nb@users.noreply.github.com；脚本及完整历史 CI 检查 |
| 项目与命名空间 | 有效 MoonBit 工程 JQ-ai-nb/joinwitness，根目录 MIT，独立业务核心 |
| 本机编译 | `moon check --target all --deny-warn` 通过 |
| 本机测试 | wasm、wasm-gc、js；35 项 MoonBit 测试，含可执行 API 文档 |
| CLI/ESM | 12 项真实集成测试通过；涵盖退出码、原始 JSON、候选结果、导出复核、非法索引 |
| 独立 SQL 对照 | SQLite 3.50.4，320 组完整来源行对集合与 MoonBit 完全一致，含四种 JOIN／两种 NULL 模式；SQLite 无独立 Boolean 类型，因此 Boolean 由独立 MoonBit oracle 覆盖 |
| 浏览器 | 本地与真实公开 Pages 的 Chromium 验证候选切换、三行下载、来源定位、覆盖率、集合差分、注入文本和 390px 布局 |
| Native／多系统 | [远程 CI 已通过](https://github.com/JQ-ai-nb/JoinWitness/actions/runs/39354229909)：Linux/macOS/Windows × wasm/wasm-gc/js/native；Windows native 使用 MSVC；未将本机缺少 SDK 当作本地 native 成功 |
| 格式与接口 | `moon fmt --check`、`moon info` 与已提交 mbti 核对 |
| 可运行入口 | `moon run cmd/demo`、Node CLI、三个交互式完整场景 |
| 包清洁 | 实际 `moon package` 归档检查通过，无 work、凭据、构建缓存和私人交付目录 |
| Mooncakes | `moon whoami` 核实 JQ-ai-nb；发布返回 200 OK；全新、无凭据的消费项目实际下载 0.1.0，校验归档 SHA256，check 与 wasm-gc/js 运行通过；见 [REGISTRY.md](REGISTRY.md) |

## 质量判断的具体依据

- 固定原始类型和 NULL 语义，避免数据库隐式强转造成无法解释的差异；完整组合键没有分隔符冲突。
- 独立双重循环 oracle 对照数万组小表内的每种 JOIN；SQLite 再对照真实 SQL 行对，而非只验证相同 count。
- 构造式三行证据经原表复核，再逐行删除验证所声明违规的最小性；缺失匹配坚持完整对表范围。
- 相同输出行数但匹配全部替换、跨租户候选键丢失覆盖、NULL 外连接来源、伪造证据、结果预算边界都有测试。
- 10000×10000 单键输入精确预检 1 亿行输出并拒绝构造，没有生成这个积；合成端到端基准可复现，不冒充生产吞吐。
- 源码与前端数据严格分工，关键计数、契约、反例、比较和结果构造都在 MoonBit。

核心物理行约 1201，测试约 725，另有 API bridge、demo 和文档测试。不将空行、模板或前端折算成有效 MoonBit 行数；比赛介绍中的规模参考不等于十月硬性行数标准。

## 本人仍须处理

正式一页 Markdown 申报书须蒋琦本人按表单要求独立编写；收到后仍须将其中承诺与实现逐条核对。联系方式、往届经历、队伍情况、银行卡及证明材料、诚信承诺、提交回执和入群由本人按真实情况完成。代码与文档公开披露 AI 辅助开发，维护者应理解并能够复现技术证据。
