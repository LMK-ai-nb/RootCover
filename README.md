# RootCover

**MoonBit 非线性约束可行域求解库：等式、不等式与带误差观测界定的可行参数区域；区域求根是其特例。**

面向机构计算、参数估计与科学模型开发者：在给定有限区域内求可行参数范围，统一输出已确认区域与未决覆盖，帮助使用者区分"唯一根 / 整盒可行 / 尚不能判定"。

核心、解析、区间导数、收缩与搜索均为 MoonBit 独立实现，不依赖 Julia、外部数值引擎或网络服务运行；成熟实现、来源与重合边界如实披露，不主张算法首创或全面超越已有求解器。

| 能力 | 接口与范围 |
| --- | --- |
| 表达式 | `+ - * /`、括号、整数幂 0…16 及负整数幂；13 种函数：sin/cos/tan/exp/log(ln)/sqrt/abs/atan/asin/acos/sinh/cosh/tanh |
| 区间计算 | 向外舍入四则、带余项界的初等函数、区间自动 Jacobian；显式定义域和光滑性状态 |
| 区域求根 | Krawczyk 唯一性证书、独立区间 Newton 收缩、传播与有界搜索；未决覆盖保留 |
| 非线性约束 | 非方等式、≤、≥、观测带；前向—反向传播、变量依赖 agenda、预条件区间 Gauss-Seidel 与坐标 Newton 联合收缩、SIVIA 内外包围 |
| 输入上限 | 1…32 变量、1…128 约束，总 AST 节点 8192、深度 64；初始盒有限，预算有限 |

**与 IntervalRootFinding.jl 0.7.2 的对照（节选）**：区域根包围与唯一性证书、13 种初等函数、区间 Newton 与联合收缩、前后向约束传播、非方约束与组合语义均为支持项（其中传播与组合语义属基准之外的扩展，见 PARITY B 表，不计入对照）；32 变量 / 128 约束是输入上限（coupled32 为 32 变量可运行算例；128 约束无公开算例，仅为解析与校验上限）。完整覆盖与"明确不做"（任意精度、符号量词、全局优化、高维保证）见 [docs/PARITY.md](docs/PARITY.md)。

## 从源码运行

MoonBit 0.1.20261021+、Node 22+。

```text
moon run cmd/demo
node scripts/build.mjs
node bin/rootcover.mjs examples/robot_roots.json
node bin/rootcover.mjs examples/robot_workspace.json
node bin/rootcover.mjs examples/thermal_parameters.json
node bin/rootcover.mjs examples/mixed_process.json
node bin/rootcover.mjs examples/robust_localization.json
node bin/rootcover.mjs examples/design_alternatives.json
node bin/rootcover.mjs examples/scaled_parameters.json
node bin/rootcover.mjs examples/coupled32.json
node bin/rootcover.mjs examples/nonlinear8.json
node bin/rootcover.mjs examples/bratu25.json
node bin/rootcover.mjs examples/design_window6.json
node scripts/serve.mjs
```

浏览器打开 http://127.0.0.1:4188 。网页、CLI 和 typed API 共享内核；Worker 计算支持停止、编辑请求、导出及传播/Newton/联合机制切换。CLI 退出码 0 表示全部分类，1 表示仍有未决，2 表示错误；上列可行域示例中 robot_workspace、thermal_parameters、mixed_process、robust_localization、design_alternatives、scaled_parameters、design_window6 退出 1 是预期结果，robot_roots、coupled32、nonlinear8、bratu25 退出 0。Mooncakes 当前为 0.2.0，本轮不通过包索引分发，请按上述命令从源码运行。coupled32.json 是 32 变量链式系统，1 次评估得到 1 个唯一根包围、退出 0；nonlinear8.json 是 8 变量三角耦合系统，1 个唯一根、无未决、退出 0；bratu25.json 是 5×5 Bratu 边值问题的二维五点耦合离散（25 变量 25 方程），4 次评估给出唯一性证书；design_window6.json 是 6 变量、5 条非方约束、至少 4 条成立的组合可行域，750 内盒 / 1798 未决。它们都是合成模型，不代表稠密或工业规模。

## 能力与版本说明

0.4新增正公式all/any/at_least、异常观测共识、逐变量绝对/相对精度、BFS与归一化/Jacobian影响划分。完整[同类检索与取舍](docs/LANDSCAPE_2026-11-13.md)、[语义和例子](docs/SET_ALGEBRA.md)。

0.5新增可行域会话：分步推进、保存/核验/恢复，保留累计预算、深度与精度，覆盖普通约束和正公式。类型化API、CLI和[浏览器分步工作台](web/session.html)共享MoonBit实现；求根模式不提供会话恢复（范围选择，见边界）。详见[SESSIONS](docs/SESSIONS.md)。

```text
node bin/rootcover.mjs examples/robust_localization.json --steps 10 --checkpoint robust.rootcover-checkpoint.json
node bin/rootcover.mjs --resume robust.rootcover-checkpoint.json --steps 20000 --checkpoint robust.rootcover-checkpoint.json
```

浏览器入口为 http://127.0.0.1:4188/session.html 。进度载入会复核轨迹，存在随记录增长的验证开销；当前不支持提高原预算或改变模型后沿用会话。

新调用使用`parse_expression`；`parse_polynomial`保持旧严格语法。`Constraint.polynomial`字段名为0.2兼容保留，其值可以是完整非线性Expr。`interval_newton`、`contract_constraints`可单独调用，返回收缩盒/空、调用次数和固定点预算状态，不单独声称可行或唯一。可执行例子见[API.mbt.md](API.mbt.md)。

## 初等函数与联合收缩场景

| 用户/用途 | 可运行输入 | 实际结果 |
| --- | --- | --- |
| 机构计算开发者求双连杆逆解及位置误差允许的关节角范围 | robot_roots.json、robot_workspace.json；三角关系和关节约束 | 精确问题两组唯一逆解；容差问题2个内盒、21个未决盒，分辨率0.02 |
| 参数估计开发者反演指数响应 `a*exp(-k*t)+b` | thermal_parameters.json；3变量、5观测/非负约束 | 537个内盒、2974个未决盒；保留(2,0.5,0.25)，分辨率1/64 |
| 科学模型开发者联立对数、根式和非线性不等式 | mixed_process.json；跨定义域初始范围 | 5个内盒、45个未决盒；保留(1,0.7)，分辨率1/64 |
| 科学计算开发者离散二维 Bratu 边值问题 | bratu25.json；5×5 内部节点、25 变量、五点耦合、exp(u) 非线性 | 4 次评估得唯一根证书 q≈0.0150，退出 0；结构化稀疏系统，不代表稠密规模 |

均为合成模型，不声称真实设备采用、统计置信度或机械安全认证。完整用户、输入、操作、输出与验证见[SCENARIOS](docs/SCENARIOS.md)。旧几何/标定/稳态/测距/重根未决/六元64根示例保留。

## 组合与精度场景

| 用户/用途 | 可运行输入 | 实际结果 |
| --- | --- | --- |
| 测量开发者在四条观测至少三条成立时定位，并保留必选边界 | robust_localization.json；嵌套all/at_least | 15内盒、38未决；保留(1,1)；严格全部满足的对照可证明空 |
| 设计开发者在指数/根式两个设计中保留任一可行方案 | design_alternatives.json；all/any与公共资源约束 | 184内盒、204未决；保留两分支，间隙不当作内盒 |
| 参数开发者分别控制百万量级偏置与千分之一增益的精度 | scaled_parameters.json；BFS、逐变量绝对/相对精度 | 226内盒、277未决；分辨率达到不代表未决可行 |
| 设计开发者在 6 个参数上要求 5 条约束至少 4 条成立 | design_window6.json；非方约束 + at_least 组合，tolerance 0.3 | 750 内盒、1798 未决、5191 次评估，resolution_met；退出 1 属预期 |

完整输入、操作与独立验证见[SET_ALGEBRA](docs/SET_ALGEBRA.md)。

## JSON调用

`mode:"roots"`或省略mode求方形系统；`mode:"feasibility"`求一般约束。约束可用`{"expression":"log(x)+y","range":[0.68,0.72]}`，或`{"expression":"x^2+y^2","relation":"<=","rhs":2}`。range与relation/rhs二选一；range的下/上端点null表示下/上无界，结果区间同理，null不代表数值0。初始box仍须有限。可用formula组合全部/任一/至少k条，search选择dfs/bfs、widest/scaled/smear及逐变量精度；见SET_ALGEBRA。

可加 `"contractors":{"propagation":true,"newton":true,"max_steps":256,"max_rounds":4}`。max_steps由全查询共享；耗尽后回到区间判定/细分，不丢待处理区域。`options`中的tolerance、max_assessments、max_depth继续有效。重复键、未知字段、任意函数调用、严格不等式及越界资源拒绝。

## 正确理解结果

唯一性仍须严格Krawczyk证据，Newton/传播负责排除和收缩。每个可行内盒中所有点满足约束；内盒∪未决包围全部可行点。未决不是可行点，盒数不是解数。显式formula时内盒证明整个正公式成立，不要求每条原子都成立；逐原子证据会导出。complete、resolution_met和收缩固定点状态分别解释。

log/sqrt/反三角定义域、除数含0、tan极点与abs非光滑区不会直接获得错误的整盒/唯一性判定。初等函数使用区间级数和余项界，不假设宿主libm误差≤1ulp；大三角参数和过宽周期逆像保守放宽。详见[NONLINEAR](docs/NONLINEAR.md)、[根语义](docs/SEMANTICS.md)、[可行域语义](docs/PAVING.md)。

## 验证与基准

```text
python -m pip install -r requirements-dev.txt
python scripts/verify.py
# 安装Playwright/Chromium后：
python scripts/verify.py --browser
```

mpmath1.3.0仅用于100位独立验证。浏览器测试另需`pip install playwright`、`python -m playwright install chromium`；可把PLAYWRIGHT_BROWSERS_PATH设在本工程work。具备本机C工具链可加`--native`。脚本记录实际命令/退出码，报告见[VALIDATION](docs/VALIDATION.md)；当前远程结果以[CI工作流](https://github.com/LMK-ai-nb/RootCover/actions/workflows/ci.yml)为准。

### 回归与消费检查

0.5 修复线程加载失败后的重试，普通浏览器验证的截图写入忽略的artifacts目录，不再改写文档图片。完整回归另包含真实Moon包的独立消费工程，每执行目标5项公开API检查；见[PACKAGE_CONSUMER](docs/PACKAGE_CONSUMER.md)。

```text
python scripts/consumer_check.py
```

[十一月规则复核](docs/RULES_2026-11-14.md)、[逐项工程验收记录](docs/ACCEPTANCE_2026-11-14.md)。源码维护与发布记录分开，不以本地开发代替官方审核。

### 基准与测试口径

实际运行Julia1.13.3 / IntervalRootFinding.jl0.7.2：20模型、Newton和Krawczyk共40次；16常规模型唯一根数量吻合，3奇异/边界模型均未决，极点处理有一处已披露差异。不是全API兼容或速度排名。[基准与复现](docs/BASELINE.md)。

MoonBit 测试在 wasm、wasm-gc、js 各 65 项通过（同一测试集，不折算为 195 个用例）；native 由 CI 的 verify.py --native 执行，本机无 MSVC，未本地实跑。另有 25 项原 CLI、8 项会话 JS/CLI 通过。旧Fraction核对继续覆盖2800组算术、182系统、513份根证据；高精度函数/导数、134模型在三种机制下共402次收缩保留继续通过。正公式另有54模型、284份精确内盒证据、162次配置收缩及24组搜索策略验证；会话另有48模型、548份状态、9074次精确内盒核对及44791次可行样本覆盖检查。有限测试不是形式化证明。

## 技术路线为什么能解决这个问题

三种常见做法各自会在哪里失效，以及本库对应的机制：

- 只做区间二分：能排除，但不能证明；重根与边界会无限细分。→ Krawczyk 唯一性证书，加未决覆盖，把"解"与"不能判定"分开。
- 只做 Newton：在区间上可能收缩为空集或发散，非方约束也无法直接套用。→ 预条件区间 Gauss-Seidel / 坐标 Newton，配合前后向传播与联合收缩，先把盒压小再判定。
- 只做盒判定：变量耦合会让盒数迅速膨胀。→ 变量依赖 agenda、传播与 SIVIA 内外包围，把"整盒可行"与"未决"分层输出。

因此它面对的是"有界非线性约束的可行域与根包围"这一类问题，而不是某个模型的一次计算；明确不做的能力列在 [docs/PARITY.md](docs/PARITY.md)。

## 目标平台与部署约束

| 约束 | 实测 |
| --- | --- |
| 运行形态 | 浏览器与 CLI 使用同一 MoonBit 内核，当前以 --target js 构建：web/engine.js 590,178 B（约 576 KiB），gzip 87,941 B（约 86 KiB，Node zlib 默认级别），不含 WebAssembly、无外部 import/require/fetch；同一内核另有 wasm / wasm-gc / native 目标用于测试与包消费 |
| 外部运行时 | 无 Julia、无 JVM、无 BLAS/LAPACK、无网络；只依赖 MoonBit 标准库与 Node/浏览器 |
| 启动与求解 | coupled32 约 0.14 s、nonlinear8 约 0.13 s、bratu25 约 0.16 s、design_window6 约 0.28 s、thermal_parameters 约 0.43 s（均含 Node 启动） |
| 资源上限 | 1…32 变量、1…128 约束、AST 8192 节点、深度 64；预算耗尽返回未决，不返回错误结果 |
| 确定性 | 同输入、同预算、同输出；证据以 JSON 导出，逐盒可复核 |

这些数字说明"浏览器与 CLI 用同一内核、可给出可复核结果"，不是性能排名；与 Julia 实现的对照只比分类与包围，不比速度。

## 为什么不直接调用 Julia / IBEX

- 运行环境：核心是 MoonBit，同一内核编到 wasm / wasm-gc / js / native 用于测试与包消费；浏览器与 CLI 当前使用 js 产物，不需要 Julia 或 JVM 运行时。
- 证据形态：内盒、未决、唯一性证书和预算语义由本库定义并可随结果导出，评审可以逐盒复核；直接调外部求解器需要在宿主侧另建一层证据映射。
- 许可证与集成：IBEX 为 LGPL-3.0，链接进分发物有额外义务；Julia 方案要求使用方部署 Julia 环境。
- 边界：如果使用方已在 Python/Julia 环境、需要任意精度或全局优化，直接用 IntervalRootFinding.jl 或 IBEX 更合适；本库不声称在这些场景更强（完整边界见下节）。
- 不移植 IBEX/Codac：其 LGPL-3.0 与 MIT 分发不兼容；C++ 实现不能作为 MoonBit 包直接消费，进浏览器还需额外 wasm 构建与许可义务。等价性改用 20 模型对照与独立 100 位核对来证明，而不是搬运代码。
- 因此本项目的定位是“MoonBit 生态内的可行域求解组件”，不是替代上述成熟实现。

## 边界与来源

实数、binary64点常数和有限初始区域。不支持任意精度、复根、整数、全局优化、任意回调/显式Jacobian、否定/量词、求根会话恢复或严格不等式。重根、边界、奇异/非光滑、宽区间、高维和资源限制均可能未决；32变量是输入上限，不是大规模完成保证。

MIT，标准库许可和NOTICE随分发保留。[调研](docs/RESEARCH.md)、[第三方来源](THIRD_PARTY_NOTICES.md)。0.3/0.4/0.5均是本仓库0.2基础上的扩展；来源、已有项目重合和未实现边界如实披露，本地开发不代表官方审核通过。
