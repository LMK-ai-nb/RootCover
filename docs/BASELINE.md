# IntervalRootFinding.jl 功能基准

这是0.3的实际Julia基准记录，0.4继续回归同一组参考；其新增BFS/相对与逐变量精度另经独立策略测试，不再属于未实现项。新的生态对照见LANDSCAPE_2026-11-13.md。

2026-11-11本地实际运行：Windows，Julia **1.13.3**、IntervalRootFinding.jl **0.7.2**、JSON3 **1.14.4**（仅参考适配器）。Julia二进制来自官方versions.json并核对SHA256；环境保存在work，不随本库分发。

原始输出：`evidence/intervalrootfinding-reference.json`；实际比较：`evidence/intervalrootfinding-comparison.json`；逐模型表见 [BASELINE_TABLE](BASELINE_TABLE.md)。不代表全API覆盖或性能排名。

## 结果

- 20模型各用Julia Newton/Krawczyk，40次实际调用，再运行本地RootCover相同请求。16常规模型双方完成分类，唯一根数量与两个方法相同，且包围与 Julia 细胞一一匹配（每个细胞恰好命中一个包围，无重复、无漏配）。覆盖初等函数、二维三角、双连杆、12/32变量耦合系统。
- abs尖点、sqrt边界、log平方重根共3模型均未决；划分不同，不比较未决盒个数。这三类属于不可证情形（非光滑、定义域边界、重根），未决不是预算耗尽的委婉说法，也不宣称加大预算即可转为确定。
- 逐模型表同时给出最大包围宽与宽度比中位数。宽度比主要反映停止精度差异（本库 tolerance 1e-7，Julia 细胞约 1e-13），不是误差指标；可核对的是根数、一一匹配与真实根落在包围内。
- `1/x=0`跨0域有一处差异：Julia保留极点未决；RootCover反向乘积传播证明定义点上分子1不可能为0，排除所有零点。不是在证明函数在0有定义，也不据此宣称整体更强。

## 当前0.5对应与缺口

| 方向 | 本地RootCover0.5 | 尚未对齐 |
| --- | --- | --- |
| 根域分类 | 唯一根证书、未决覆盖、绝对容差/预算 | 仅有限模型对照，不是全库兼容 |
| 表达式 | 固定安全语法与13种函数 | 任意Julia函数组合和更多特殊函数 |
| 导数 | 自身区间前向AD | 自定义Jacobian回调 |
| Newton | 独立预条件区间Gauss-Seidel/坐标Newton及联合收缩 | 唯一根证书仍是Krawczyk，不声称复刻Julia Newton全部证书机制 |
| 搜索 | 有界DFS/BFS、绝对/相对与逐变量精度、宽度/归一化/Jacobian影响划分 | 外部可迭代搜索状态、持久化恢复；划分启发式不声称完整复刻IBEX |
| 数值基础 | binary64、域/光滑性状态、保守函数包围 | 任意精度、全decorations、IEEE-1788完整实现 |
| 非方约束 | 等式、≤、≥、观测带，SIVIA+前后向传播+Newton | roots基准不等于完整约束框架；该层另参考IBEX概念，也未全面对齐IBEX |

0.5可行域另有可复核会话恢复（SESSIONS.md）；上表根搜索的迭代/恢复缺口仍然存在。

## 复现

独立Julia工程安装IntervalRootFinding0.7.2和JSON3 1.14.4后：

```text
julia --project=work/julia-project tests/baseline/intervalrootfinding.jl artifacts/intervalrootfinding-reference.json
node scripts/build.mjs
moon build tests/probe --target js --release --deny-warn
python scripts/compare_intervalrootfinding.py
```

本机设置私有JULIA_DEPOT_PATH避免污染其他工程。未来CI读取实际产生的参考JSON作回归，不自动下载Julia；不能称每次CI都现场运行Julia。

## 来源与许可

[根接口](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/roots/)、[内部机制](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/internals/)、[保证](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/decorations/)。本轮[实际读取MIT许可](https://github.com/JuliaIntervals/IntervalRootFinding.jl/blob/master/LICENSE.md)，纠正初次GitHub元数据NOASSERTION的不完整记录；没有复制其求解实现。模型采用文档常见数学例子和自建合成模型，适配器独立编写。

[IBEX传播/HC4说明](https://ibex-lib.readthedocs.io/en/latest/contractor.html)为概念参考，上游LGPL-3.0；没有移植或链接上游代码。
