# 可行域层的跨语言核对（手写 SIVIA）

可行域/传播层此前只有自测。这里补一个**跨语言参考实现**：用 Julia 1.13.3 + IntervalArithmetic（IntervalRootFinding 0.7.2 的依赖）另写一个 SIVIA，只负责纯合取约束的两个场景，比体积覆盖率，不比盒数（两边切分规则不同）。

这是一次**参考核对**，不是与 IBEX/Codac 的成熟实现对照：参考实现是为本次核对手写的（`scripts/sivia_reference.jl`），只覆盖两个场景，不能替代完整 SIVIA 实现。

## 场景与容差

| 场景 | 变量 | 容差 | Julia 内盒 | Julia 外包围 | RootCover 内盒 | RootCover 外包围 |
| --- | --- | --- | --- | --- | --- | --- |
| robot_workspace | 2 | 0.02 | 3.1e-5（1 盒） | 7.63e-4（24 边界盒） | 2.6e-5（2 盒） | 4.59e-4 |
| thermal_parameters | 3 | 0.0625 | 0（74 边界盒） | 1.81e-2 | 0（0 内盒） | 1.29e-2 |

## 读法

- **内盒体积**：两场景都没有矛盾。`robot_workspace` 的已证明可行体积同量级（3.1e-5 vs 2.6e-5，差约 16%）；`thermal_parameters` 在 0.0625 精度下两边都没有整盒可行——该可行域是一条薄片，粗精度下不可整盒证明，这与"盒数多不等于区域大"一致。
- **外包围**：RootCover 在两个场景都更紧（约小 1.4–1.7 倍），与收缩器的预期作用一致；这不是"更强"的证明，只是同一容差下的覆盖差异。
- **盒数不可比**：参考实现按最宽维中点二分，RootCover 用变量依赖 agenda 与收缩，切分不同。

## 复现

```text
# 参考实现（离线，需 Julia 1.13.3 与 work/julia-depot）
JULIA_DEPOT_PATH=work/julia-depot work/julia-baseline/julia-1.13.3/bin/julia.exe \
  --project=work/julia-project scripts/sivia_reference.jl
# 数据：docs/evidence/sivia-cross-language.json

# RootCover 同容差
node bin/rootcover.mjs examples/robot_workspace.json
```

参考实现不在 `verify.py` 的 CI 步骤内：CI 不安装 Julia。
