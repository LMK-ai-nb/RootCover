# 选题调查、已有项目与独立价值

调查时间：2026-11-03/04。覆盖Mooncakes本地registry的3556个模块元数据、GitHub公开README/仓库元数据/部分源码、MoonBit社区站点检索及成熟外语项目。`moon update`本次曾因网络失败，不能把本地快照当作整个生态在提交时刻的完整清单；私有工程、未发布代码和所有历史版本未全面查证。原始快照保存在独立本地调研目录，不随本库分发。提交前另定向扫描mbmath的122份、floating的433份源码/文档，检索并阅读相关求根接口；关键词未命中不能充当不存在功能的证明。

## 首轮三个候选，均因核心重合放弃

| 候选、用户与真实问题 | MoonBit已查证项目 | 外语成熟项目、许可与局限 | 结论 |
| --- | --- | --- | --- |
| 拓扑数据分析：图像/点云工具开发者跨阈值识别连接分量和孔洞，避免单阈值失真 | [moontopolens](https://github.com/wdgodghl/moontopolens)，MIT；registry 0.20.8描述H0/H1/H2、图像拓扑、批量聚类和稳定性 | [GUDHI](https://github.com/GUDHI/gudhi-devel)，C++/Python完整TDA体系；GitHub元数据MIT，组件许可未逐文件审计。规模和功能远超轻量新库 | 核心需求已覆盖，放弃，未复用代码 |
| Unicode双向排版：编辑器/PDF开发者处理阿拉伯语、希伯来语与拉丁文混排 | [unicode-bidi](https://github.com/moonbit-community/tonyfettes-unicode)，Apache-2.0；已提供UAX9实现及Unicode相关基础库 | [ICU](https://github.com/unicode-org/icu)，成熟Unicode实现；多份许可未逐文件核验。标准算法本身已有成熟实现 | 同主题核心重合，放弃，不以重写或换名申报 |
| Datalog递归查询：数据/图分析开发者表达递归关系和分层否定 | [moondatalog](https://github.com/haol-05/moondatalog)，Apache-2.0，递归、分层否定、聚合和静态检查；另有dowdiness的关系计算组件 | [Soufflé](https://github.com/souffle-lang/souffle)，UPL-1.0，成熟编译型Datalog。不是只有简单递归示例 | 独立价值不足，放弃 |

补充考察过概率图推断，但[moon-bayes-kit](https://github.com/tyytyy68/moon-bayes-kit)（Apache-2.0）README已经包含离散因子和贝叶斯网络，不能依据一句“在线更新库”就认定它不覆盖核心需求，因此也未选用。外语[pgmpy](https://github.com/pgmpy/pgmpy)为MIT，有成熟概率/因果推断。

上述社区搜索未提供完整的实时项目目录；没有相关检索结果不等于无竞品。候选许可证仅用于如实比较，没有导入或移植这些工程。

## 选择RootCover的理由

RootCover从多元多项式**根区域求解**起步，0.2补充观测带可行域。从用户指定的有限区域计算可确认根域、无根排除和未决覆盖，服务几何交点、逆向标定与科学平衡模型；不是已有库的审计器、适配包装或某个业务系统的附属品。数值算术是必要基础，主要交付在区间Jacobian、Krawczyk求解及全区域搜索。

| 最接近的项目 | 已查证能力 | 本项目已实现贡献 | 调查/能力边界 |
| --- | --- | --- | --- |
| [Luna-Flow/floating](https://github.com/Luna-Flow/floating)，Apache-2.0 | 任意精度二进制/十进制、向外舍入区间、明确状态和数值语义 | 在独立binary64实现之上交付多元方程根域搜索、严格唯一性、显式未决和应用接口 | 底层区间四则存在实质能力交集，不把它们重新发明当作创新；本库不提供其任意精度和完整数值规范能力 |
| [CAIMEOX/mbmath](https://github.com/CAIMEOX/mbmath)，Apache-2.0 | README明确包含区间算术和数值求根等，不能隐瞒 | 本版实际具备初始区域覆盖、Krawczyk证据和预算耗尽的未决输出；通过独立Fraction/AST核对 | 未声称它所有求根接口都不可能做类似事情。已定向读取findroot_interval：要求端点包根的一维二分，返回单个RawMpf近似值；findroot2为有限差分Jacobian的二维Newton。未逐一运行全部接口，不宣称完全无重叠 |
| [numsolve](https://github.com/noweizongqing/numsolve)，registry Apache-2.0 | Mooncakes元数据与缓存README说明数值求根、ODE、线性系统、插值 | 关注给定区域的可确认根数与不能判定的剩余区域，实际接口与场景公开 | 初次API读取404，随后成功读取当前源码包（25份源码/文档），roots.mbt有bisection和newton等数值接口。未全面运行其全部API，不断言绝无重合 |
| [IntervalRootFinding.jl](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/)，Julia | 多维区间求根、保证/未决状态，已存在完整成熟的同类方法 | 独立MoonBit实现、无外部数值运行时、typed/CLI/浏览器共享内核，精确有理数测试证据 | 不是方法首创或功能领先；GitHub许可元数据NOASSERTION，未逐文件核对，不复制代码 |
| [IBEX](https://ibex-lib.readthedocs.io/en/latest/)，LGPL-3.0 | 工业级区间约束、收缩器、系统求解与全局优化 | 聚焦有界多项式根域的独立小内核与跨目标集成 | 不具备其通用表达式、超越函数、全局优化与成熟工业规模能力 |

检索词包括 interval arithmetic、interval Newton、Krawczyk、root isolation、root boxes、all roots、非线性、求根、区间。社区检索结果包含区间树、类型变量消去等无关命中，不能混作数值求解竞品。实际的相邻能力和成熟外语方案已经披露。

## 独立价值仍需要评审判断

可确认的贡献是能运行的求解层和诚实的结果分类，不能仅靠名称、MoonBit语言或页面漂亮推出独立性。本工程不声称“全世界唯一”“与任何生态无重合”或“保证初审”。评委可能认为仅支持多项式和有限维度仍偏窄；目前没有真实用户采用或大型工业模型证据。优先改进方向是经许可的实际模型、病态系统与规模评测，不通过追加未实现承诺扩大申报范围。

来源许可、AI辅助、无移植代码及旧工程关系见THIRD_PARTY_NOTICES.md与ORIGIN.md。

## 0.2 扩展的查重与独立贡献

再次检索当前本地公开注册表快照3562个模块，词包括SIVIA、set inversion、continuous/interval constraint、Krawczyk、root enclosure。元数据命中RootCover与moonallen的定性时序区间；这不是全生态不存在同类的证明。结合前述源码对比，本次补的是多项式输出观测带的连续可行域内外包围，支持非方约束，并非把算术或已有近似根接口换名。

需继续披露[moonplan](https://github.com/cn-xjr/moonplan)有限域约束/调度、[cad_sketch](https://github.com/mik1e80/moonbit-cad-sketch)小型二维非线性草图求解等相邻方向；按公开资料比较，未运行其所有接口。不能据此声称几何/约束需求没有交集。RootCover当前实际输出整盒可行证据及未决覆盖，独立必要性仍由评审判断。

成熟[IBEX](https://ibex-team.github.io/ibex-lib/lab.html)已覆盖SIVIA等方法。概念参考其公开说明和[2016年集合反演论文](https://reliable-computing.org/reliable-computing-22-pp-104-115.pdf)，没有复制代码，不声称方法新发明。本版也不具备其完整收缩器、超越函数、优化或工业规模能力。

已进一步读取cad_sketch当前README：它输出候选坐标/半径与逐约束诊断，明确说明依赖初值，尚未实现不等式和全局搜索。RootCover不提供其草图对象、24种设计关系和编辑流程；已实现的区别是有限区域的根分类与观测带可行集合内外包围。此对照不构成跨库性能/精度领先声明，具体以引用版本的公开接口和边界为准。
