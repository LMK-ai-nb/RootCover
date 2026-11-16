# 区域求根语义（0.4 起实现，0.5 沿用）

只讨论有限初始盒内、所有表达式有定义的实零点；complete不表示区域中处处有定义，也不表示区域外无根。系数/边界按binary64点值解释。

- 先求区间值和Jacobian，范围不含0或处处未定义可排除；只有整个证明域有定义且光滑，才执行证明性Krawczyk判定。
- 中心Jacobian近似逆Y只作预条件；向外舍入构成Krawczyk映像。严格位于原盒内部且q<1才返回Certificate，证书的domain包含恰好一个根，enclosure包含该根。
- 区间Newton和前后向传播可排除/收缩，非空收缩不证明存在根。本版唯一性证书仍是Krawczyk，未复刻JuliaNewton的所有证书机制。
- 所有丢弃部分由范围、传播或区间线性化排除。根路径可能在父域内适度放宽过窄的收缩盒，便于严格内部存在性证明；不会因此丢根。
- 待处理盒在预算/深度/精度/域边界/非光滑/奇异限制下保留unresolved。complete仅在无未决时为true；tolerance_met只描述已认证根的最终包围宽度，不能替代complete。
- 闭子盒共享界面；边界根/重根可能始终未决，不能以残差小、盒小或Newton近似点代替证明。

默认联合收缩，contractors.max_steps为全查询共享调用预算；耗尽后继续原区间判定/细分。固定点状态不代表最强收缩。

0.4可选DFS/BFS、逐变量绝对/相对精度及划分启发式；策略仅改变顺序和停止宽度，不改变证明谓词。导出search说明实际配置；assessment预算尚未处理的盒标pending，其余未决标unknown，均不当作根或排除区域。具体精度、跨零和未实现恢复的边界见[SET_ALGEBRA](SET_ALGEBRA.md)。

初等函数、定义域处理、SIVIA语义和不支持范围见[NONLINEAR](NONLINEAR.md)、[PAVING](PAVING.md)。参考基准与差距见[BASELINE](BASELINE.md)。有限测试不是形式化证明。

## 结果字段（0.5.1）

| 字段 | 适用 | 含义 |
| --- | --- | --- |
| `status` | 可行域 | `satisfied`（complete 且有内盒）、`unsatisfiable`（complete 且无内盒）、`unknown`（仍有未决） |
| `counts` | 可行域 | `inside` / `unknown` / `pending` / `excluded`，四类互斥；`unknown + pending = unresolved_count` |
| `unresolved_count` | 可行域 | 未决盒总数 |
| `options` | 根与可行域 | 本次实际生效的 tolerance、max_assessments、max_depth |
| `contractors` | 根与可行域 | propagation、newton、max_steps、max_rounds |
| `roots[].certificate` | 根 | 唯一性证书：domain、enclosure、image、preconditioner、contraction_bound |

逐盒的 `status` 只在 `unresolved[]` 内出现，取值 `pending`（预算耗尽或会话暂停）或 `unknown`（分辨率/深度/域边界等原因）。
