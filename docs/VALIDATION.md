# 0.5 本地实际验证

## 0.5.0维护记录（2026-11-14，形成于dev.2）

完整本地检查增加真实Moon包消费步骤，包含独立工程每目标5项接口测试；本地三个目标均执行。线程模块失败/重试和原有两个工作台的浏览器回归通过。命令仍为`python scripts/verify.py --browser`；本轮24步记录及源码哈希见evidence/maintenance-2026-11-14.json。C工具链可用时传--native，三平台CI会实际运行native。普通截图和浏览器JSON结果写入artifacts；仅设置ROOTCOVER_UPDATE_SCREENSHOTS=1时更新文档截图。

## 0.5.0-dev.1历史本地记录

完整本地验证2026-11-13；版本0.5.0-dev.1。此记录及local-0.5证据反映推送前快照；后续源码/网页/远程CI状态见RELEASE.md。历史公开0.1/0.2验证见RELEASE.md；0.3证据保留于evidence/local-0.3-validation.json，不当作新版证据。

## 已执行命令

`python scripts/verify.py --browser` 的所有23步退出0。完整原始命令/输出在忽略的artifacts/validation.json，公开摘要及16个核心文件SHA256见[evidence/local-0.5-validation.json](evidence/local-0.5-validation.json)。

- 本地Windows；moon0.1.20261021 / moonc0.10.17+093cb8f9c。
- `moon check --target all --deny-warn`通过。wasm、wasm-gc、js分别实际test/build，每目标65项测试全通过（含9项公开API文档测试）。同一测试集在三个目标上重复验证，不当作195个不同用例。
- fmt严格检查、moon info接口、typed demo、JS桥接构建、32项CLI与8项会话JS/CLI均通过，包含六场景×DFS/BFS共12组对照及真实跨进程恢复、原子替换。
- 原求根Fraction：2800算术、182系统、513份唯一性证据重放。
- 可行域Fraction：37系统、1215份内盒证据、4413有理数网格点；覆盖域内包含、正体积不重叠、叶数守恒和可行样本保留。
- 新独立mpmath1.3.0，100位：525表达式盒、4076函数值、5900解析导数；134模型在三种机制下共402次收缩核对、21114网格检查；19非线性根系统、3新增可行域场景、14562内盒端点/中心检查。
- 新正公式独立参考：54个有理数模型、284份内盒公式证据、920个可行有理数样本；162次配置收缩保留2760个可行样本；24组根搜索策略组合；3个新场景的3825个内盒高精度采样点。命令为`python tests/predicate_oracle.py`，原始结果在artifacts/predicate-oracle.json。
- Julia1.13.3 / IntervalRootFinding0.7.2实际运行所得20模型、Newton和Krawczyk40次参考保存在evidence/intervalrootfinding-reference.json。本轮将当前RootCover重新对照该参考；没有每次重跑Julia。16常规模型两方法根数吻合、3奇异/边界模型均未决、1极点差异如实披露；见BASELINE.md。
- 实际Chromium：六个新增可行域场景、机制/搜索切换、正公式报告下载、原场景、预算、重复JSON键、注入文本、乱序加载、取消和390px布局全部通过。桌面和390px截图另经人工视觉检查。
- 真实Moon包已打包并扫描：16个核心文件在包中，work/私人材料/缓存/联系方式不在包中。该检查不执行publish；最终包文件数/字节数以本地package-check.json为准。

## 0.5会话补充

- 独立Fraction：48模型、548份状态、9074次内盒证据复核、44791次可行样本覆盖检查；240次轨迹修改中190拒绝，其余50仍通过覆盖/证据核对。状态和内盒跨多次暂停重复检查，不当作不同数学问题。命令`python tests/session_oracle.py`，结果在artifacts/session-oracle.json。
- 第二工作台真实Chromium：10步保存、刷新载入后仍为10步、继续到110步；伪造内盒拒绝；取消保留上一步；结果导出及390px布局通过。桌面/移动截图经视觉核对。
-0.3/0.4历史公开摘要继续保留，不作为0.5新增功能证据。原有算术、根、可行域、初等函数与Julia参考回归持续通过。

## 验证边界

本机未配置MSVC/Windows SDK，未本地 build/run native，只有静态 check；远程 CI 已在 `baf8f20` 上执行 `verify.py --native`，native 口径以该 run 为准，不把 0.2 的远程 native 成功当作新版证据。

原Fraction参考不复用MoonBit实现；100位参考独立解析AST、使用解析AD，避免用有限差分在极大/极小尺度产生假零导数。正公式参考用Fraction计算区间/点值与组合真值；高精度场景参考沿用独立解析器。采样在高精度域构造，避免次正规区间的插值点下溢跑出输入范围。它们仍是有限回归，不是形式化证明或所有模型的可靠性保证。

所有示例合成，无真实设备/工业采用、统计置信度或安全认证结论。高维上限不等于能在给定预算内完成；病态、重根、域边界和精度限制可能未决。
