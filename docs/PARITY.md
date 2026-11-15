# 能力覆盖：以 IntervalRootFinding.jl 为基准

评审建议以 [IntervalRootFinding.jl](https://github.com/JuliaIntervals/IntervalRootFinding.jl) 为求根能力基准，并补充约束传播、组合语义与可行域会话，形成相对完整的非线性约束可行域求解能力。本文把"做了什么、做到什么程度、明确不做什么"一次写清，避免把范围问题留成想象空间。

基准版本：IntervalRootFinding.jl **0.7.2**（Julia 1.13.3，2026-11-11 本机实测，见 [BASELINE.md](BASELINE.md)）。对照不是全 API 兼容声明，也不是性能排名。

## A. 与 IntervalRootFinding.jl 0.7.2 直接对应的求根能力

| 能力 | RootCover 0.5 | 边界说明 |
| --- | --- | --- |
| 区域根包围、唯一根证书、未决覆盖 | 支持 | Krawczyk 唯一性判定；20 模型 × Newton/Krawczyk 40 次实测，16 个常规模型根数吻合、包围逐一相交 |
| 常见初等函数 | 13 种 + 除法与整数幂 | 固定安全语法；不支持任意 Julia 函数组合与更多特殊函数 |
| 定义域与光滑性 | 显式建模 | 不实现 IEEE-1788 完整 decorations |
| 区间 Newton 收缩 | 支持 | 独立预条件区间 Gauss-Seidel / 坐标 Newton，配合联合收缩；不声称复刻 Julia 的全部 Newton 证书机制 |
| 搜索策略 | DFS / BFS | 绝对、相对与逐变量精度；划分启发式不复刻 IBEX |
| 规模 | ≤ 32 变量、128 约束 | `examples/coupled32.json` 为 32 变量可运行算例，128 约束无公开算例仅为上限；上限不是高维完成保证 |
| 数值基础 | binary64 向外舍入 | 不含任意精度 |
| 交付形态 | MoonBit 库 + CLI + 浏览器 | 同一核心，无外部数值运行时 |

## B. 基准之外的可行域扩展（IntervalRootFinding.jl 无对应项，不计入覆盖率）

| 能力 | RootCover 0.5 | 边界说明 |
| --- | --- | --- |
| 前后向约束传播 | 支持 | 概念参考 IBEX contractor，未移植、未链接上游代码 |
| 非方约束与组合语义 | 支持 | 等式、≤、≥、观测带；全部 / 任一 / 至少 k 条；该层超出 roots 基准，另参考 IBEX 概念 |
| 可行域会话 | 支持 | 仅可行域模式：分步、保存、核验载入、继续；求根模式无恢复；文件恢复有核验开销 |

## 结论

A 组逐项对应 IntervalRootFinding.jl 0.7.2 的求根能力；B 组是可行域方向的扩展，基准库不提供这些能力，因此不参与覆盖率计算。B 组参考了 IBEX/Codac 的公开概念，但只实现传播与组合语义的一个子集，不主张达到其工业级完整度，也不主张算法首创。

明确不做的是：任意精度、符号量词与否定、全局优化、高维完成保证、全 API 兼容。这些是范围选择，不是未完成项——写在这里，便于评审区分"没做"与"不做"。

## 复核入口

- 基准记录与缺口表：[BASELINE.md](BASELINE.md)
- 生态对照：[LANDSCAPE_2026-11-13.md](LANDSCAPE_2026-11-13.md)
- 验收证据：[ACCEPTANCE_2026-11-14.md](ACCEPTANCE_2026-11-14.md)
- 复现命令：见 BASELINE.md「复现」一节（Julia 参考结果已落盘为 JSON，CI 不现场下载 Julia）
