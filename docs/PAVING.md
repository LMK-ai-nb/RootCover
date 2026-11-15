# 非线性约束可行域（0.4 起实现，0.5 沿用）

ConstraintModel接受1…128个实表达式观测带，1…32变量，可非方、欠定或超定。Constraint.polynomial为兼容保留字段名，可以放置完整非线性Expr。

本文下述逐约束求交语义针对默认ConstraintModel/无formula请求。0.4的显式PredicateProblem/formula支持all/any/at_least；其集合、内盒证据与定义域规则以[SET_ALGEBRA](SET_ALGEBRA.md)为准，不能把“每条约束均成立”套用于备选分支。

## 输入

JSON `mode:"feasibility"`，约束使用`expression`与`range:[a,b]`，或`relation:"=="/"<="/">="`与有限rhs，不能混用。range下/上端点null表示下/上无界，结果区间同样编码；它不是数值0。初始变量盒必须有限。区间都是闭的；不支持严格不等式。

允许的集合S只含所有表达式有定义且满足约束的点。部分定义域可保留不确定，但处处未定义会排除。绝不能仅凭中点可行判定整盒可行。

## 算法和覆盖

联合前向—反向传播、预条件区间Gauss-Seidel和坐标Newton先保守收缩，再用自然区间像判定/细分：

- Inside：整个盒有定义，且每条表达式的完整区间像都包含在允许带中。
- Outside：至少一条表达式处处未定义、区间像与允许带不交，或可靠收缩器证明无解。
- 其余保留并细分；资源限制则直接放入unresolved。

输出满足 `union(inside) ⊆ S ⊆ union(inside, unresolved)`。所有被收缩去掉部分均不能含可行点。SIVIA与传播使用成熟方法，不是首次发明；参考[IBEX](https://ibex-lib.readthedocs.io/en/latest/contractor.html)。

complete表示无未决，resolution_met仅表示所有未决盒达到要求宽度。宽度默认按tolerance，也可使用search中的逐变量绝对/相对精度；不以宽度代替可行判定。definitely_empty只有complete且inside为空才为true。可行盒是连续点集，数量不等于根数/连通分支数，也不输出root_count。观测带不是统计置信度或系数不确定族。

## 预算与局限

全查询共享contractors.max_steps；每次收缩还限max_rounds。额度耗尽不宣称固定点，不丢待处理盒；改用区间判定和细分。搜索另受max_assessments/max_depth和精度控制，可选DFS/BFS。输出status=pending专指assessment预算耗尽而未处理的盒，其他不能判定的盒为unknown；两者均在unresolved中。0.5可行域会话另支持分步暂停和可复核序列化，见SESSIONS.md；不能把单次结果直接当作检查点。

宽自然区间像、周期逆像凸包、高维、奇异、厚度很窄、域边界或资源限制都可能产生大量未决。固定点不保证全局最优或存在可行点，不支持优化目标/整数/任意精度。具体算法见[NONLINEAR](NONLINEAR.md)。
