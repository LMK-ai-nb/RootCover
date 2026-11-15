# 标准对齐（STANDARDS）

版本 0.5.0（`moon.mod:3`）。本文把 Krawczyk 唯一性证书、SIVIA 集合反演和 IEEE 1788 区间算术的要求逐条对到本仓库源码。只写代码里能指认的行为；没有对应实现的假设直接写“未实现/未检查”。行号按当前工作区源码核对，格式为 `文件:行`；函数名用于在文件内检索。

本文不是合规声明，也不是形式化证明。Krawczyk 证书是“可重放的输入与计算结果”，不是本库自带的独立证明检查器；IEEE 1788 部分只覆盖 set-based flavor 的一个子集，明确不声称 conforming implementation。

## 1. Krawczyk 唯一性证书

### 标准要求

设 X ⊂ R^n 是有限盒，F: X → R^n 在 X 上连续可微；J(X) 是包含所有 F'(x) 的区间矩阵，Y 是 F'(mid) 的近似逆。定义

```text
K(X) = mid − Y·F(mid) + (I − Y·J(X))·(X − mid)
```

若 K(X) ⊂ int(X)，则 X 内存在唯一零点；K(X) ∩ X 可作为新的根包围。证书至少要能重放 X、mid、Y、J(X)、F(mid)、K(X) 与收缩界，而不是只给一个浮点近似根。

### 逐条映射

| 定理成分 / 检查 | 代码位置 | 代码实际行为 |
| --- | --- | --- |
| 方形系统与有限盒 | `polynomial.mbt:97 validate_system`；`polynomial.mbt:133 check_box`；`krawczyk.mbt:156 assess` | 方程数必须等于变量数（`polynomial.mbt:98`）；变量 1…32、表达式 1…128（`polynomial.mbt:110-114`）；盒端点必须有限且有序（`polynomial.mbt:136-138`）。非方系统不会进入 Krawczyk 证书。 |
| F ∈ C¹(X) 与定义域 | `krawczyk.mbt:83 evaluate_unchecked`；`polynomial.mbt:194 evaluate_unchecked`；`expression.mbt:4 expression_range_unchecked`；`elementary.mbt:378 elementary` | 整盒处处无定义 → `Excluded`（`krawczyk.mbt:84-86`）；值域不含 0 → `Excluded`（`krawczyk.mbt:87-89`）；`fully_defined` 或 `smooth` 为假 → `Undecided`，不做唯一性判定（`krawczyk.mbt:90-92`）。`fully_defined`/`smooth` 是表达式层逐点复合后的保守布尔状态（`polynomial.mbt:200-207`），不是对 C¹ 的机器证明。 |
| 区间 Jacobian 包含 | `polynomial.mbt:144 dual`；`polynomial.mbt:194 evaluate_unchecked` | 前向区间自动微分；`Evaluation.jacobian` 是区间矩阵（`polynomial.mbt:25-31`）。加减乘幂商与初等函数导数都通过向外舍入的 `Interval` 运算得到。`abs` 跨 0 时 `unary_slope` 返回 `whole()`（`expression.mbt:70-95`），同时 `smooth=false`，因此不会拿这个导数去做证书。 |
| Y ≈ F'(mid)⁻¹ | `krawczyk.mbt:93-99`；`krawczyk.mbt:24 inverse` | `center` 取每个区间的 `midpoint()`（`krawczyk.mbt:93`）；在中心点求值（`krawczyk.mbt:94`）；把中心 Jacobian 的每个区间元素取中点后做带部分主元的浮点高斯-约当求逆（`krawczyk.mbt:24-66`）。主元为 0/NaN/Inf，或逆矩阵出现非有限值 → `None`，`assess_unchecked` 返回 `Undecided`（`krawczyk.mbt:95-99`）。`Y` 只是预条件矩阵，证明算术仍用区间。 |
| K(X) 的构造 | `krawczyk.mbt:78 assess_unchecked`；`krawczyk.mbt:100-126` | 先算区间矩阵 B = I − Y·J(X)（`krawczyk.mbt:100-108`），再逐坐标算 `image[i] = mid_i - Σ_k Y[i][k] F_k(mid) + Σ_j B[i][j] (X_j - mid_j)`（`krawczyk.mbt:117-126`）。`F(mid)` 来自中心点盒的 `evaluate_unchecked` 结果 `at_center.ranges`（`krawczyk.mbt:94`）。 |
| 收缩界 q | `krawczyk.mbt:78 assess_unchecked`；`krawczyk.mbt:109-116` | 对 B 的每一行取元素 `magnitude()`，每次累加用 `next_up` 向外扩，取最大行和。q 是 I − Y·J(X) 的无穷范数上界。 |
| K(X) ⊂ int(X) | `krawczyk.mbt:78 assess_unchecked`；`krawczyk.mbt:128-137` | `strict = q < 1.0`（`krawczyk.mbt:128`）；每个坐标同时要求 `image[i].lo > box[i].lo && image[i].hi < box[i].hi`（`krawczyk.mbt:134`）。任一坐标不满足就不进入 `Unique`。先做 `box[i] ∩ image[i]`，交集为空 → `Excluded`（`krawczyk.mbt:130-133`）；`narrowed` 是交后的根包围（`krawczyk.mbt:127-137`）。 |
| 证书字段 | `krawczyk.mbt:5-12 Certificate`；`krawczyk.mbt:138-146` | `domain = X`，`center = mid`，`preconditioner = Y`，`image = K(X)`，`enclosure = X ∩ K(X)`，`q = 收缩界`。返回 `Unique(...)` 时这些字段一次性写入（`krawczyk.mbt:138-146`）。 |
| JSON 导出 | `format.mbt:182-237 result_json` | 每个根输出 `enclosure` 与 `certificate`；`certificate.method` 固定为 `"krawczyk_strict_contraction"`（`format.mbt:188`），`domain`/`image`/`center`/`preconditioner` 原样序列化，`contraction_bound` 取 `c.q`（`format.mbt:195`）。 |
| 根结果与细化 | `solver.mbt:14-17 RootBox`；`solver.mbt:77 solve_configured`；`solver.mbt:113-140` | `RootBox.enclosure` 是最终根包围。得到 `Unique` 后，用 `enclosure` 再评估最多 12 次；只接受更小的 `Unique`/`Contracted` 包围（`solver.mbt:117-139`），不改变原始存在唯一性证明。`Contracted` 不是唯一性证书。 |
| 测试反例 | `krawczyk_wbtest.mbt:2-45` | 线性系统得到严格多元证书（`krawczyk_wbtest.mbt:2-18`）；x²+1 被区间值域排除（`krawczyk_wbtest.mbt:21-27`）；x² 在 [-1,1] 上因中心 Jacobian 奇异而未决（`krawczyk_wbtest.mbt:30-36`）；x=0 落在 [0,1] 边界时不被认证为 `Unique` 或 `Excluded`（`krawczyk_wbtest.mbt:39-45`）。 |

### 字段语义：不要把 q 当成唯一性假设

- `domain` 是证书盒 X，不是根包围。它回答“在哪个盒里证明了唯一性”，不回答“根具体在哪”。
- `enclosure` 是根包围，即 X ∩ K(X)（`krawczyk.mbt:127-137`）。在严格内部成立时它通常就是 K(X)；不严格时它是交，可能只用于收缩。
- `image` 是 K(X)；`preconditioner` 是浮点矩阵 Y；`center` 是 mid。
- `q` 是 `||I − Y·J(X)||∞` 的向外上界，是**收缩充分条件**。代码把 `q < 1` 作为额外的严格门槛，和逐坐标 `image ⊂ int(box)` 一起才返回 `Unique`（`krawczyk.mbt:128-146`）。`q < 1` 本身不是定理的“唯一性假设”，也不能单独推出唯一性。
- JSON 里的 `contraction_bound` 就是源码字段 `q`（`format.mbt:195`）；源码中没有名为 `contraction_bound` 的结构体字段。
- `Certificate` 不单独保存 J(X) 与 F(mid)：它们可由原请求的 system 和 `domain` 重算。JSON 证书也不内嵌 system，完整重放需同时保留原请求。

### 偏离 / 没做什么

- 没有独立证明检查器。`Certificate` 是可重放的输入与计算结果，不是可由第三方 checker 独立验证的证明对象；本库不提供“证书一旦导出就被机器证明”的保证。
- `fully_defined`/`smooth` 是表达式层的保守状态，不是 C¹ 的形式化证明；不检查高阶导数、Lipschitz 常数，也不处理区间系数或参数不确定性。
- 区间 Jacobian 的包含性依赖 `Interval` 的向外舍入与 `dual` 前向 AD 的正确性；本库没有独立的包含性检查或形式化验证。
- `Y` 是浮点逆，不是区间逆；接近奇异的中心 Jacobian 可能给出 `q ≥ 1` 或直接 `Undecided`。没有 Hansen–Sengupta、区间 Gauss–Seidel 证书或 Miranda 定理证书。
- 只支持方形系统（方程数 = 变量数，`polynomial.mbt:98`）。非方等式/不等式只能走可行域 `pave`，不会生成 Krawczyk 唯一性证书。
- 边界根、重根、非光滑点、定义域边界不会被认证为唯一；`Undecided` 与 `Contracted` 都不等于“无根”。
- 不证明初始盒外无根。`complete` 的语义限于初始盒（`solver.mbt:25-28`）。
- binary64、1…32 变量；没有任意精度、复数、高维完成保证或大规模性能保证。
- 没有把 Krawczyk 证书用于非方约束系统；可行域的内盒/未决覆盖是另一套语义（见下一节）。

### 参考

- R. Krawczyk, “Newton-Algorithmen zur Bestimmung von Nullstellen mit Fehlerschranken,” *Computing* 4, 1969.
- A. Neumaier, *Interval Methods for Systems of Equations*, Cambridge University Press, 1990.

## 2. SIVIA（集合反演）

### 标准要求

SIVIA 从有限初始盒开始，维护待处理盒集合；对每个盒做 inclusion test：

1. 若整个盒满足约束，记为 inner（可行内盒）；
2. 若整个盒与约束不相交，丢弃（outside）；
3. 否则为 unknown，二分后继续。

对 unknown 盒反复细分，直到盒宽不超过 ε，或达到深度/预算限制。最终 inner 的并集是可行集的**内包围**，inner ∪ unknown 是**外包围**。SIVIA 输出的是集合包围，不是根计数、概率/置信区间或优化器；`unknown` 盒既不是可行点，也不是不可行点。

### 逐条映射

| SIVIA 步骤 | 代码位置 | 代码实际行为 |
| --- | --- | --- |
| 待处理集合与栈式细分 | `search.mbt:81 WorkQueue`；`search.mbt:88 WorkQueue::new`；`search.mbt:117 WorkQueue::take`；`search.mbt:144 WorkQueue::children`；`paving.mbt:144`；`paving.mbt:152-214` | 显式 `WorkQueue`，不是递归栈。`DepthFirst` 从尾部 `pop`，`BreadthFirst` 从 `head` 前移（`search.mbt:117-132`）。默认 `DepthFirst`（`search.mbt:24-31`）。子盒由 `children` 按搜索顺序压入：DFS 先右后左，BFS 先左后右（`search.mbt:144-160`）。 |
| inclusion test（inside/outside/unknown） | `paving.mbt:69 classify_unchecked`；`paving.mbt:24 FeasibilityAssessment` | 对每条约束取 `expression_range_unchecked`。`range=None` → `Outside`（`paving.mbt:78-81`）；区间像与允许带严格不相交（`r.hi < allowed.lo` 或 `r.lo > allowed.hi`）→ `Outside`（`paving.mbt:83-85`）；所有约束 `fully_defined` 且 `r.lo >= allowed.lo && r.hi <= allowed.hi` → `Inside`（`paving.mbt:86-92`）；否则 `Indeterminate`（`paving.mbt:94`）。`Inside` 认证整个盒，不认证中点（`paving.mbt:99`；测试 `paving_wbtest.mbt:15-18`）。 |
| 二分 | `search.mbt:165 split_with_policy` | 沿一个轴在 `0.47*lo + 0.53*hi` 处切（`search.mbt:203`）；要求切点严格位于盒内部且可表示（`search.mbt:204-205`）；没有可切轴 → `None`，调用方记为未决 `"no representable interior split point"`（`paving.mbt:206-210`）。切分轴按 `Widest`/`Scaled`/`JacobianImpact` 选择（`search.mbt:208-217`）。 |
| ε 停止 | `search.mbt:70 precision_met`；`search.mbt:55 axis_precision`；`paving.mbt:184-190` | 逐轴检查 `width <= max(absolute_tolerance, relative_tolerance * min_abs)`；`min_abs` 在含 0 的盒上取 0（`search.mbt:65`），避免相对精度把零附近的根藏掉。达到精度 → 未决原因 `"resolution reached without whole-box classification"`（`paving.mbt:185-188`）。 |
| 预算/深度停止 | `paving.mbt:132 pave_configured`；`paving.mbt:155-158`；`paving.mbt:191-193`；`solver.mbt:2-6 Options` | `assessments >= max_assessments` → 未决 `"assessment budget exhausted"`（`paving.mbt:155-158`）；`depth >= max_depth` → 未决 `"depth limit reached"`（`paving.mbt:191-193`）。未决盒保留，不丢弃。 |
| inner / outer 输出 | `paving.mbt:34-44 PavingResult`；`paving.mbt:181`；`paving.mbt:185-210`；`paving.mbt:218-219` | `inside` 是整盒可行的内盒（`paving.mbt:181`）；`unresolved` 是未决盒（`paving.mbt:185-210`）。因此 `inside ∪ unresolved` 是初始盒内全部可行点的外包围。`complete = unresolved.is_empty()`（`paving.mbt:218`）；`resolution_met = unresolved.all(precision_met)`（`paving.mbt:219`）。 |
| contractor-first | `paving.mbt:118 pave`；`paving.mbt:160-179` | `pave` 默认带 contractors（`paving.mbt:118`）。在 inclusion test 之前先做 `contract_unchecked`：收缩为空 → 计入 excluded；非空 → 用收缩后的盒替换原盒（`paving.mbt:160-179`）。`changed` 只用于计数收缩次数，不改变“替换”的事实。这不是 textbook SIVIA 的“纯区间判定再细分”流程。 |
| 共享预算 | `paving.mbt:160-168`；`solver.mbt:2-6`；`docs/NONLINEAR.md:48` | `options.max_assessments` 是全查询共享；`contractors.max_steps` 也是全查询共享，`contractor_calls` 耗尽后回到区间判定/细分，不丢待处理区域（`paving.mbt:160-168`）。不是每个盒独立预算。 |
| 语义测试 | `paving_wbtest.mbt:34-35`；`paving_wbtest.mbt:61-62`；`paving_wbtest.mbt:87`；`paving_wbtest.mbt:104` | 存在未决但全部达到精度时 `complete=false`、`resolution_met=true`（`paving_wbtest.mbt:34-35`）；预算耗尽时两者都为 false（`paving_wbtest.mbt:61-62`）；完全分类时 `complete=true`（`paving_wbtest.mbt:87`、`104`）。 |

### 偏离 / 没做什么

- **contractor-first**：`pave` 默认先传播/Newton 收缩，再做 inclusion test 和细分（`paving.mbt:160-179`）。这减少了盒数，但流程已经不是经典 SIVIA 的“只做 inclusion test + 二分”；未决原因也可能来自收缩预算而非分类。
- **BFS/DFS 可选**：默认 `DepthFirst`，可通过 `search.strategy` 选择 `bfs`（`search.mbt:3-6`、`search.mbt:24-31`、`search.mbt:245-252`）。两者只影响调度，不改变证明谓词（`search.mbt:1-2`）。
- **共享预算**：`max_assessments` 和 `contractors.max_steps` 都是全查询共享，不是每盒独立额度；预算耗尽会把剩余盒放进 `unresolved`（`paving.mbt:155-168`）。
- **`resolution_met` 只针对未决**：它表示所有 `unresolved` 盒都达到精度（`paving.mbt:219`），不表示可行域已被完全分类，也不表示未决盒可行。`complete=false` 仍可能 `resolution_met=true`，即已经按 ε 覆盖但仍有未决（`paving_wbtest.mbt:34-35`）；反之 `resolution_met=false` 时 `complete` 也一定为 false。
- **没有单一 subpaving 对象**：结果只给 `inside` 与 `unresolved` 盒数组，调用者要自己取并集；不输出规则化网格、连通分支或覆盖率数值。
- **`inside ∪ unresolved` 是外包围**：`inside` 是已证可行，`unresolved` 不是可行点；盒数不是根数、连通分支数或概率。
- **只支持正向约束**：等式、≤、≥、观测带与正公式；没有否定/补集、量词、严格不等式或优化目标（`docs/NONLINEAR.md:54`）。
- **没有独立 ε-cover 证书**：`resolution_met` 只是宽度检查，不是覆盖率证明；高维、宽区间、周期逆像、奇异/非光滑区域仍可能大量未决（`docs/PAVING.md:23`、`docs/PAVING.md:29`）。
- **没有全局优化/LP/ACID**：不输出最优值，也不做线性松弛、3B/ACID 或 Polytope Hull（`docs/REVIEW_RESPONSE.md:12`、`docs/LANDSCAPE_2026-11-13.md:20`、`docs/LANDSCAPE_2026-11-13.md:52`）。

### 参考

- L. Jaulin and E. Walter, “Set inversion via interval analysis for nonlinear bounded-error estimation,” *Automatica* 29(4), 1993.
- L. Jaulin, M. Kieffer, O. Didrit, E. Walter, *Applied Interval Analysis*, Springer, 2001.

## 3. IEEE 1788（区间算术标准）

### 标准要求

IEEE 1788-2015 为 set-based flavor 定义区间类型、基本运算与初等函数的**向外舍入/保守包围**，并定义 decoration（`ill`、`trv`、`def`、`dac`、`com`）及其传播格：`trv` 无信息，`def` 表示函数在整盒有定义，`dac` 表示整盒有定义且连续，`com` 还要求结果是 common interval（有界非空）；运算结果的 decoration 按格传播。此外，Kaucher/modal 区间、任意精度、exact dot product 等常见扩展/可选能力也不在本库范围。

本库只实现 set-based flavor 的一个子集：binary64 闭区间、向外舍入四则/幂/除法、初等函数的保守包围，以及 `DomainRange` 状态到 decoration 术语的**文档级保守解释**。本库没有 decoration 类型，也不传播 decoration。

### 逐条映射

| 标准要素 | 代码位置 | 代码实际行为 |
| --- | --- | --- |
| set-based 区间类型 | `interval.mbt:3 Interval`；`interval.mbt:32 interval`；`interval.mbt:45 whole` | 闭区间 `{lo, hi}`，没有 decoration 字段。公开构造拒绝 NaN 和 `lo > hi`（`interval.mbt:32-37`）；内部 `whole()` 可产生无界端点（`interval.mbt:45-47`）。 |
| 向外舍入 | `interval.mbt:15 next_up`；`interval.mbt:27 next_down`；`interval.mbt:55 width`；`interval.mbt:65 add`；`interval.mbt:81 sub`；`interval.mbt:86 mul`；`interval.mbt:110 power`；`elementary.mbt:62 div` | 加、减、乘、幂、宽度都在 binary64 上向外扩一端；`neg` 与 `intersection` 是精确端点运算。`next_up`/`next_down` 使用位模式相邻值，保留次正规数（`interval.mbt:14-29`）。 |
| 基本运算的保守性 | `interval.mbt:65 add`；`interval.mbt:86 mul`；`interval.mbt:110 power`；`elementary.mbt:62 div`；`elementary.mbt:82 divided` | `mul` 取四个端点乘积的 hull（`interval.mbt:86-106`）；`power` 对偶次幂利用非负性（`interval.mbt:110-129`）；`div` 在分母含 0 时返回 `whole()`（`elementary.mbt:62-67`）；`divided` 对 `0/0` 返回 `point(0)` 并标记 `fully_defined=false`（`elementary.mbt:82-90`）。这些是保守包围，不追求 IEEE 1788 的最紧除法语义。 |
| 初等函数的保守包围 | `elementary.mbt:378 elementary`；`elementary.mbt:4-18 Unary` | 13 个一元函数：sin/cos/tan/exp/log/sqrt/abs/atan/asin/acos/sinh/cosh/tanh。exp/log/sin/cos/atan 用区间级数与显式余项界；sqrt 用浮点位模式二分；asin 用有界单调区间二分；acos 由 π/2−asin 构成（`docs/NONLINEAR.md:9-13`）。`tan` 在 `cos` 含 0 时返回 `whole()` 并标记不光滑（`elementary.mbt:384-392`）；参数绝对值大于 1e6 的三角函数返回 `[-1,1]`（`elementary.mbt:198-213`、`250-253`）；`log`/`sqrt`/`asin`/`acos` 在定义域外返回 `range=None`（`elementary.mbt:395-438`）。这是保守包围，不是“宿主 libm 误差 ≤1 ulp”的假设（`docs/NONLINEAR.md:7-16`）。 |
| `DomainRange` | `elementary.mbt:45-49 DomainRange`；`expression.mbt:4 expression_range_unchecked` | `range=None` 表示整个盒上表达式处处未定义；否则 `range` 是定义点的保守像。`fully_defined` 表示整盒每点有定义；`smooth` 表示整盒满足可微条件（保守布尔，`docs/NONLINEAR.md:20-24`）。 |
| `fully_defined`/`smooth` → decoration（保守解释） | `elementary.mbt:45-49 DomainRange`；`expression.mbt:4-57 expression_range_unchecked` | 见下表。该表只是把已有布尔状态翻译成 IEEE 1788 术语，**不是库输出的 decoration**。 |
| 证明门控 | `krawczyk.mbt:78 assess_unchecked`；`krawczyk.mbt:90-92`；`docs/NONLINEAR.md:24` | 只有 `fully_defined && smooth` 才允许做 Krawczyk/Newton 证明性收缩；否则只做值域排除、域传播与细分。 |

`DomainRange` 的保守映射：

| `DomainRange` 状态 | 可保守解释为 | 依据与限制 |
| --- | --- | --- |
| `range=None` | `trv`（无可用区间） | 整盒处处未定义，最保守。本库不构造 `ill`；非法端点/NaN 在公开构造处已被拒绝（`interval.mbt:32-37`）。 |
| `Some(r)` 且 `!fully_defined` | `trv` | 只在有定义点给像，整盒不保证有定义；可能跨极点或定义域边界（`elementary.mbt:82-90`、`395-438`）。 |
| `Some(r)`、`fully_defined=true`、`smooth=false` | `def` | 整盒每点有定义，但可能有尖点/不可微点（如 `abs` 跨 0、`sqrt` 在 0、`tan` 极点附近）；`def` 不承诺连续性。 |
| `Some(r)`、`fully_defined=true`、`smooth=true` | `dac` | 可微 ⇒ 连续，且整盒有定义；这是本库能保守支持的最高常用级别。 |
| 上一行且 `r` 有界（`Interval::finite`，`interval.mbt:148-154`） | `com` 候选 | 若调用者额外确认结果是 common interval（有界非空），可按 IEEE 术语解释为 `com`；库本身不检查/不输出 `com`，也不传播 decoration。 |

### 未实现 / 不声称

- 没有 decoration 类型、decoration 传播格或 `com/dac/def/trv` 的运算；上表只是文档级解释。调用方拿不到 decoration 字段。
- 没有 Kaucher/modal 区间、反向运算、完整区间关系谓词、标准文本 I/O 或 decorated interval 的解析/格式化。
- 没有任意精度/多倍精度；只有 binary64 `Double`（`interval.mbt:3-6`、`polynomial.mbt:2`）。
- 没有 exact dot product、FMA 或“正确舍入的初等函数”。初等函数用区间级数 + 余项界保证保守，但不声称每个端点都是 IEEE 1788 要求的正确舍入值（`docs/NONLINEAR.md:7-16`）。
- 没有复数区间、矩阵区间标准运算、interval Newton 的标准 API；`div` 对含 0 分母统一返回 `whole()`，不是完整 IEEE 1788 除法语义（`elementary.mbt:62-67`）。
- 没有 `ill`/`ein` 等特殊 decoration；输入校验直接拒绝 NaN/非法区间（`interval.mbt:32-37`）。
- 13 个一元函数之外（`atan2`、`min`/`max`、实数幂、gamma 等）未实现；没有用户函数/回调（`parser.mbt:154`、`README.md:11`、`README.md:151`）。
- 大参数三角、宽区间、周期逆像会保守放宽，不保证最紧包围（`elementary.mbt:198-213`、`250-253`）。
- **不声称 conforming implementation，也不声称通过 IEEE 1788 测试套件。** 本库只对齐 set-based flavor 的一个可审计子集，且证书/分类仍受 binary64 与有限预算限制。

### 参考

- IEEE Std 1788-2015, *IEEE Standard for Interval Arithmetic*, 2015.
- R. Krawczyk, “Newton-Algorithmen zur Bestimmung von Nullstellen mit Fehlerschranken,” *Computing* 4, 1969.
- A. Neumaier, *Interval Methods for Systems of Equations*, Cambridge University Press, 1990.
