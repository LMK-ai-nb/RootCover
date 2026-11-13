# 同类项目检索、缺口与本轮取舍

检索日期2026-11-13。本轮在本地0.3基础上扩展到0.4.0-dev.1，未推送/发布。比较的是本地实现，不能拿线上0.2的能力冒充新版。

同日0.5另补可行域会话保存/核验/恢复，见SESSIONS.md；根搜索恢复仍未实现。下述外部项目调查与0.4取舍继续保留，能力以当前文档为准。

## 调查范围与证据强度

重新拉取Mooncakes公开索引，扫描3761份用户模块元数据；较宽的interval/nonlinear/constraint/求根等关键词命中46项，随后复核已知相邻项目。还搜索GitHub、MoonBit官方/社区页面和下面成熟项目的一手文档/许可。原始快照在忽略的work/research-2026-11-13。

这不是“全世界没有相似项目”的证明。未逐一运行所有项目或审计全部版本、私有工程和未发布代码；社区未命中不能当不存在。除已有Julia真实基准外，本表多数是文档/接口对照，不作跨库速度或精度领先结论。

## 成熟外语项目

| 项目及来源 | 已查证能力与我们原来的缺口 | 本轮取舍 |
| --- | --- | --- |
| [IntervalRootFinding.jl](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/roots/)，MIT；另见[搜索内部机制](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/internals/) | Newton/Krawczyk根分类、绝对/相对容差、广度/深度搜索和可迭代状态 | 已补BFS和相对精度；显式Jacobian回调、可恢复搜索/完整Newton证书机制仍未实现。之前20模型40次实际运行见BASELINE.md |
| [IBEX策略](https://ibex-team.github.io/ibex-lib/strategy.html)、[求解器组成](https://ibex-team.github.io/ibex-lib/solver-prog.html)，LGPL-3.0 | 按变量设置精度、smear划分、COV区分pending/unknown；还具备ACID、线性松弛/Polytope Hull等高级机制 | 已补逐变量绝对精度、Jacobian影响启发式和pending标签；不声称复刻完整smear或实现LP/ACID/持久化COV |
| [Codac组合算子](https://codac.io/manual/contractors/index.html)，LGPL-3.0 | 交/并、q交、separator、投影、几何与动态约束；我们的模型此前只有全约束AND | 已补正公式all/any/at_least及保守阈值收缩。没有移植Codac，也未实现完整双向separator、否定、投影或动态tubes |
| [IntervalConstraintProgramming.jl](https://github.com/JuliaIntervals/IntervalConstraintProgramming.jl)，[MIT许可](https://raw.githubusercontent.com/JuliaIntervals/IntervalConstraintProgramming.jl/master/LICENSE.md) | 可组合实不等式与内/边界可行域近似，集合操作是既有能力 | 借鉴可复用集合建模思想，独立实现正公式与逐原子证据；不宣称集合约束算法首创 |
| [RealPaver](https://github.com/realpaver/realpaver)，[MIT许可](https://raw.githubusercontent.com/realpaver/realpaver/main/COPYING) | 连续约束、区间Newton/一致性技术，现代构建还支持LP和局部优化后端 | 区间安全和分支保留作为验证重点；本轮不引入LP、整数或优化后端 |
| [dReal](https://dreal.github.io/)，[Apache-2.0](https://raw.githubusercontent.com/dreal/dreal4/master/LICENSE) | 非线性实公式与δ判定、SMT接口等 | 仅作为语义边界参考。RootCover的内盒/未决不是δ-sat，不实现或冒称δ-complete/SMT/量词求解 |

特别核对了[Codac CtcQInter接口](https://raw.githubusercontent.com/codac-team/codac/codac2/src/core/contractors/codac2_CtcQInter.h)：其q为**最多允许违反的约束数**，我们的count为**最少成立的子谓词数**。二者不能直接互换。没有复制其算法实现；本轮用坐标端点覆盖计数构造必要外包围，并以独立有理数参考检查解保留。

## MoonBit生态相邻项目

| 项目、已复核版本/来源 | 已有能力与我们的交集 | 缺口/选择 |
| --- | --- | --- |
| [Luna-Flow/floating](https://github.com/Luna-Flow/floating)，索引0.10.2，Apache-2.0 | 任意精度binary/decimal及带显式语义的区间算术；底层区间运算存在重合 | 我们没有任意精度和完整decorations，不把四则重写当创新；本轮聚焦上层可行域与逻辑组合。未全面运行其API |
| [CAIMEOX/mbmath](https://github.com/CAIMEOX/mbmath)，索引名CAIMEOX/moon_floating0.3.1，Apache-2.0 | 任意精度、实/复区间、特殊函数、数值求根和科学计算 | 高精度/特殊函数/ODE仍是我们的缺口；没有借它们扩大未实现承诺。独立贡献在区域分类、逻辑观测组合和未决覆盖，不宣称所有求根接口无交集 |
| [cad_sketch](https://github.com/mik1e80/moonbit-cad-sketch)，0.3.0，Apache-2.0 | 草图实体、24类关系、参数编辑、逐约束诊断与SVG，输出候选近似几何 | RootCover不实现其完整CAD建模流程；我们提供一般表达式区域求解及厚观测逻辑组合。不能把几何场景说成没有其他求解器 |
| [MoonPlan](https://github.com/cn-xjr/MoonPlan)，0.1.0，Apache-2.0 | 有限域/排班、命名约束和不可满足冲突解释 | 我们不提供离散排班或最小冲突集；只能逐盒给出区间/原子真值证据，不把它冒称全局冲突解释 |
| [MoonCassowary](https://github.com/sgy1023-crt/MoonCassowary)，0.2.1，BSD-3-Clause | 增量线性约束、软优先级、编辑建议 | 我们没有线性tableau增量编辑/软目标；BFS不是增量求解，不混淆用途 |
| numsolve0.6.0（本次索引元数据） | 元数据包含ODE、线性系统、求根与插值 | 本轮公开仓库/文档链接读取失败，最新具体API尚未查证；不据此断言它缺少某能力。旧版本源码调查仍保留于RESEARCH.md |

已读README快照包含固定提交：floating81242fa、mbmath6c7f181、MoonPlanccfb441、MoonCassowary19f431f。不能把README对照称作完整实现/维护质量审计。

## 为什么优先这两组补强

1. **可组合非线性约束**：四条观测至少满足三条且必选规则不许放松；或两种方案任选其一。解决异常观测、多模式设计的具体问题。全部/任一/阈值逻辑不等于把所有约束强行求交。
2. **适合实际量纲的搜索**：offset在百万量级、gain在千分之一量级时分别要求精度，并选择BFS/归一化或Jacobian启发式。终止精度、根存在性和整盒可行性分别报告。

没有以“多加函数/多写代码”证明创新。本轮是同一RootCover的实质扩展，已有成熟外语方案覆盖这些思想；是否符合本月独立生态价值仍需评审判断。

## 后续可借鉴、但本轮未承诺的能力

- 搜索状态序列化/恢复、可迭代API、预算增量继续（IRF/IBEX）；0.5已实现可行域轨迹核验恢复；根搜索状态、预算增量和外部迭代仍未实现。
- 自定义Jacobian、纯Newton唯一性证书、额外常见函数如atan2/min/max。
- 3B/ACID、线性松弛和高效稀疏线性代数；可选数值后端/任意精度与完整区间装饰语义。
- 否定/严格开边界、完整separator、投影和量化参数约束；动态tube、全局优化、整数/SMT不属于本轮已实现范围。
- 真实用户模型、病态/高维大规模性能与独立形式化审计。

## 与通知的关系

用户提供的初审通知指出旧项目范围偏窄，并允许2026年11月30日前补充修改材料；截图没有给出具体小时，不能推出23:59或验收截止。此处只记录用户提供的信息，不冒称已取得新的公开规则或重新审核结果。

本地实现、公开仓库、申报正文必须最终一致。当前新增能力仍只在本地；未重新提交、未通过初审，也不能保证修改后通过。
