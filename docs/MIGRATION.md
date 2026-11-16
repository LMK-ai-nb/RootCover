# 迁移说明（MIGRATION）

版本 0.5.0（`moon.mod:3`）。本文回答两个问题：谁适合把现有求解流程迁到 RootCover；迁移要付什么、会失去什么、最小接入怎么做。只写仓库能支撑的事实，所有成本与损失都给出文件或命令依据。

迁移的正当理由只有三条：运行时不需要 Julia/JVM（`README.md:133`、`README.md:142`）、计算可离线在本地完成（`README.md:133`、`web/worker.js:1-3`）、证据随结果以 JSON 导出（`README.md:136`、`format.mbt:182-237`）。迁移理由不是性能或能力排名；仓库明确说对照只比分类与包围，不比速度（`README.md:138`、`docs/BASELINE.md:7`）。

因此，只有以下条件同时成立时，重做/迁移才值得：目标环境无法安装 Julia/JVM（`README.md:133`、`README.md:142`），模型或数据不能离开本机/浏览器（`README.md:133`），并且需要把内盒、未决与证书逐盒导出给 CI/评审（`README.md:136`、`format.mbt:182-237`）。如果已有 Julia/IBEX 环境且需要任意精度或全局优化，迁移不划算，继续用成熟工具更合适（`README.md:145`、`README.md:151`）。

## 1. 谁会用它

以下是**目标用户假设**，不是采用记录。仓库内没有真实用户、工业模型或生产部署证据；现有算例都是合成模型（`README.md:40`、`docs/REVIEW_RESPONSE.md:60`）。三类假设：

1. **MoonBit 生态内的团队**：假设 MoonBit 生态内缺少可直接复用的同类可行域库，团队需要在 MoonBit/wasm 内做有界非线性约束的可行域或根包围，但不想引入 Julia/JVM 或 C++ 求解器。依据是项目定位为“MoonBit 生态内的可行域求解组件”（`README.md:147`）；`docs/LANDSCAPE_2026-11-13.md:28-35` 的相邻项目表里没有列出与本库相同的“整盒可行 + 未决覆盖”接口。但 `docs/RESEARCH.md:43` 明确说注册表扫描“不是全生态不存在同类的证明”，所以这只是可检验的假设，不是已证事实。
2. **浏览器/边缘**：模型不能出机，计算必须在本地完成。依据是运行时无 Julia/JVM、无网络（`README.md:133`），浏览器 Worker 直接调用同一 JS 内核（`web/worker.js:1-3`），结果以 JSON 返回（`README.md:136`）。
3. **CI/评审流水线**：需要把每次运行的 `inside`、`unresolved`、唯一性证书逐盒存档，而不是只拿到一个浮点根。依据是 `format.mbt:182-237` 输出逐盒 `roots`/`certificate`/`unresolved`，CLI 退出码区分全部分类/仍有未决/错误（`README.md:40`）。

再次强调：以上三类都是**目标用户假设**；仓库内没有采用证据。`docs/RESEARCH.md:43` 的生态检索也明确不是“不存在同类”的证明。

## 2. 迁移要付什么

| 成本 | 依据 | 具体表现 |
| --- | --- | --- |
| 受限表达式语法 | `parser.mbt:237-244`；`parser.mbt:154`；`elementary.mbt:4-18`；`README.md:11`；`README.md:151` | 只接受 `+ - * /`、括号、整数幂 0…16（负幂由 `Div(1, Pow(...))` 表示，`parser.mbt:87-108`）和 13 个一元函数（sin/cos/tan/exp/log/sqrt/abs/atan/asin/acos/sinh/cosh/tanh）。没有用户函数、回调、复数、任意 Julia 函数组合或自定义 Jacobian；未知函数名直接报错（`parser.mbt:154`）。输入上限为 1…32 变量、1…128 约束、AST 8192 节点、深度 64（`polynomial.mbt:110-114`、`polynomial.mbt:58`、`polynomial.mbt:86`）。 |
| JSON 字符串入口 | `bridge/main.mbt:3 run_request`；`format.mbt:241 solve_json`；`format.mbt:77-93` | JS 侧必须 `JSON.stringify` 请求、`JSON.parse` 结果；`run_request(source: String) -> String` 接收的是整段 JSON 文本。请求上限 256 Ki UTF-16 单元，重复键、未知字段、非有限数字、过大嵌套会被拒绝（`format.mbt:76-93`）。 |
| 同步调用 | `bridge/main.mbt:3-13`；`web/worker.js:1-3` | `run_request` 直接返回字符串，没有 Promise/回调；长请求会占住调用线程。仓库的浏览器实现把调用放进 Worker（`web/worker.js:1-3`），但这是使用方自己做的隔离，不是 API 的异步能力。 |
| 每个 Worker 一个 session | `bridge/main.mbt:16`；`bridge/main.mbt:29-52`；`web/session-worker.js:1-3`；`docs/SESSIONS.md:32` | `active_session` 是模块级 `Ref` 单例（`bridge/main.mbt:16`）；`run_session` 没有 session id，`start/restore/advance` 都操作这个槽（`bridge/main.mbt:29-52`）。同一 JS realm 只能有一个 active session；并发会话需要多个 Worker 或串行化请求。 |
| 求根模式无会话恢复 | `session.mbt:49 new_paving_session`；`solver.mbt:58 solve`；`README.md:46`；`docs/SESSIONS.md:55`；`docs/PARITY.md:26` | `new_paving_session` 只解析可行性请求（`session.mbt:49`），会话只覆盖可行域模式；求根仍是单次 `solve`（`solver.mbt:58`），中断后只能重跑，不能从证书或未决盒恢复。 |
| 0.5 未发布到包索引，需 vendor 源码/产物 | `moon.mod:3`；`README.md:40`；`docs/RELEASE.md:8`；`.gitignore:8`；`.gitignore:11`；`scripts/build.mjs:5-8`；`package.json:7` | Mooncakes 仍是 0.2.0（`README.md:40`、`docs/RELEASE.md:8`），`moon add` 拿不到 0.5。`dist/` 与 `web/engine.js` 都被 gitignore（`.gitignore:8`、`.gitignore:11`），新克隆没有可直接 import 的产物；需要 `node scripts/build.mjs`（要求 Node 22+ 与 MoonBit 工具链）或自行 vendor 构建出的 `engine.js`。`dist/engine.js` 和 `web/engine.js` 是同一份构建产物（`scripts/build.mjs:8`）。 |
| 单次求解的输入/输出形状 | `format.mbt:165-178`；`polynomial.mbt:133-139`；`bin/rootcover.mjs:31` | 结果端点用 `null` 表示无界（`format.mbt:172-178`），但初始盒仍必须有限（`polynomial.mbt:136-138`）。CLI 动态 import `../dist/engine.js`（`bin/rootcover.mjs:31`），产物缺失会直接失败。 |

## 3. 会失去什么

| 失去的能力 | 依据 | 说明 |
| --- | --- | --- |
| Julia/IBEX 的速度与生态 | `README.md:138`；`docs/BASELINE.md:7`；`README.md:145`；`docs/RESEARCH.md:31` | 仓库没有做速度基准，也没有 Julia/IBEX 的生态；对照只比分类与包围（`README.md:138`、`docs/BASELINE.md:7`）。已有 Julia/Python 环境且需要成熟生态时，直接用 IntervalRootFinding.jl 或 IBEX 更合适（`README.md:145`）。迁移不能用性能优势作为理由。 |
| 任意精度 | `README.md:151`；`docs/PARITY.md:17`；`docs/BASELINE.md:24` | 只有 binary64；没有多倍精度、精确十进制或区间系数族。 |
| 全局优化 | `README.md:151`；`docs/PARITY.md:32`；`docs/REVIEW_RESPONSE.md:12` | 不提供优化目标、最优值或全局优化；输出是可行域/根包围。 |
| LP/ACID/线性松弛 | `docs/REVIEW_RESPONSE.md:12`；`docs/LANDSCAPE_2026-11-13.md:20`；`docs/LANDSCAPE_2026-11-13.md:52` | 未实现 LP、3B/ACID、Polytope Hull、高效稀疏线性代数或持久化 COV。 |
| 完整 decoration | `docs/PARITY.md:13`；`docs/BASELINE.md:24` | 只有 `DomainRange` 的保守解释；不输出、不传播 IEEE 1788 decoration（详见 `docs/STANDARDS.md` 第 3 节）。 |
| 成熟支持与工业证据 | `README.md:147`；`docs/REVIEW_RESPONSE.md:60`；`README.md:40` | 定位是 MoonBit 生态组件，不是成熟实现的替代；真实用户需求、工业模型、高维/病态性能仍缺证据，算例是合成模型。 |
| 复数/整数/量词/否定/严格不等式/回调 | `README.md:151`；`docs/NONLINEAR.md:54`；`docs/BASELINE.md:21` | 不在语法或 API 内；没有自定义 Jacobian 回调，也没有 NOT/量词/完整 separator。 |
| 高维/工业规模保证 | `README.md:151`；`docs/PARITY.md:17` | 32 变量是输入上限，不是大规模完成保证；高维仍受维数灾难影响。 |

### 不适合迁移的三种情形

1. **已经在 Julia/Python 环境，且需要任意精度、全局优化或 LP/ACID**：直接用 IntervalRootFinding.jl 或 IBEX 更合适（`README.md:145`、`README.md:151`、`docs/PARITY.md:32`、`docs/REVIEW_RESPONSE.md:12`）。迁移不会补上这些能力。
2. **需要完整 IEEE 1788 decorations、Kaucher/modal 区间、exact dot product 或正确舍入的初等函数**：这些未实现，本库只对齐 set-based flavor 的一个子集（`docs/PARITY.md:13`、`docs/BASELINE.md:24`；详见 `docs/STANDARDS.md` 第 3 节）。
3. **需要工业级高维模型、复数根、用户自定义函数/回调，或正式证明检查与成熟商业支持**：本库是 1…32 变量的有限盒求解器，证书不是独立证明对象，也没有真实工业采用证据（`README.md:151`、`docs/RESEARCH.md:37`、`docs/REVIEW_RESPONSE.md:60`；证书边界见 `docs/STANDARDS.md` 第 1 节）。这类需求应继续使用成熟工具。

## 4. 最小接入示例

前提：Node 22+（`package.json:7`）。从源码使用时先构建：

```text
node scripts/build.mjs
```

该脚本要求本机有 MoonBit 工具链（`scripts/build.mjs:5`），并把同一份产物写到 `dist/engine.js` 与 `web/engine.js`（`scripts/build.mjs:8`）。若已 vendor 了 `engine.js`，可跳过构建。

把下面 8 行保存为 `migration-example.mjs`（与 `dist/` 同级）：

```js
import { run_request } from './dist/engine.js';

const request = {
  version: 1, variables: ['x', 'y'],
  equations: ['x+y-3', 'x-y-1'], box: [[0, 4], [0, 4]]
};
const result = JSON.parse(run_request(JSON.stringify(request)));
console.log('root_count =', result.root_count); // 1
```

浏览器内把 import 路径换成 `./web/engine.js`（同一份构建产物，`scripts/build.mjs:8`）；`run_request` 仍是同步调用，建议放在 Worker 中（`web/worker.js:1-3`）。

实际运行输出（在本仓库根目录执行）：

```text
root_count = 1
```

同一临时脚本额外打印 `complete` 与第一个根的 `enclosure`，得到：

```text
complete = true
enclosure = [[1.9999999999999956,2.000000000000005],[0.9999999999999959,1.0000000000000044]]
```

即该 2 变量线性系统在 `[0,4]×[0,4]` 内给出 1 个唯一根，包围在 `(2,1)` 附近；`complete=true` 表示本次运行没有未决盒。

## 如何验证本文档

以下三条命令均在仓库根目录执行：

```text
# 1) 构建并运行上面的最小示例（示例已保存为 migration-example.mjs）
node scripts/build.mjs && node migration-example.mjs
# 期望：root_count = 1

# 2) 跑一个已知二变量求根算例
node bin/rootcover.mjs examples/robot_roots.json
# 期望：root_count 2，complete true，退出码 0

# 3) 跑 CLI 与会话测试
node --test tests/cli.test.mjs tests/session.test.mjs
# 期望：39 pass，0 fail（HEAD；工作区若有未提交的会话测试则为 40）
```

标准对齐部分的函数与行号可用 `grep -n` 直接复核，例如：

```text
grep -n "fn assess_unchecked\|let mut strict\|contraction_bound" krawczyk.mbt format.mbt
grep -n "fn precision_met\|fn split_with_policy\|fn classify_unchecked" search.mbt paving.mbt
```
