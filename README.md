# RootCover

**用同一套MoonBit区间内核，计算多项式方程的根与带观测容差的可行区域。**

面向几何、标定软件与科学模型开发者：从指定有限区域出发，求根模式区分唯一解域与未决区域；可行域模式区分整盒可行区域与未决覆盖，支持观测带数量多于变量数量的模型。预算耗尽时保留所有待处理区域。

维护者与参赛者：**李明坤 / LMK-ai-nb**，个人参赛。AI辅助开发，由维护者复核、理解和解释。来源与旧工程关系见[ORIGIN](docs/ORIGIN.md)。

[GitHub](https://github.com/LMK-ai-nb/RootCover) · [在线工作台](https://lmk-ai-nb.github.io/RootCover/) · [Mooncakes](https://mooncakes.io/docs/LMK-ai-nb/rootcover) · [实际发布记录](docs/RELEASE.md)

![区间工作台](docs/assets/workbench.png)

## 五分钟运行

当前版本0.2.0：本地moonc 0.10.17 / moon 0.1.20261021已验证；远程moonc 0.10.19在Windows、macOS、Linux的四个目标全部通过。Mooncakes发布和独立下载运行已成功，证据见RELEASE.md。Node22+运行CLI和网页，Python3.12+仅用于验证，无第三方npm或Python运行时依赖。

```text
moon run cmd/demo
node scripts/build.mjs
node bin/rootcover.mjs examples/geometry.json
node bin/rootcover.mjs examples/calibration.json
node bin/rootcover.mjs examples/equilibrium.json
node scripts/serve.mjs
```

打开 http://127.0.0.1:4188。网页/CLI均调用同一份MoonBit数值内核，网页使用Worker运行并支持停止、编辑请求、切换分支、加入观测容差、限制预算和导出原始请求/结果。运行时不调用外部数值API。修改MoonBit后重新build。

CLI也支持 `node bin/rootcover.mjs examples/noisy_localization.json` 与 `examples/calibration_band.json`。这两类观测带示例保留未决区域，**退出码1是预期结果**：0表示所有区域已分类，1表示仍有未决，2表示无效输入/宿主错误。`resolution_met=true`不替代`complete=true`。

## 两类完整计算

| 模式 | 输入 | 返回 |
| --- | --- | --- |
| roots（默认） | 1…6个变量、等数量多项式、有限初始盒 | 区间Jacobian、Krawczyk排除/收缩、严格唯一解域、根包围与未决区域 |
| feasibility | 1…6个变量、1…32个多项式观测带、有限初始盒 | SIVIA区域划分、整盒可行证据、未决外包围、分辨率/资源状态 |

核心区间运算、表达式解析、自动微分、两类搜索与结果判定均由MoonBit实现，无第三方数值引擎、绑定或服务代理。两类方法是既有数值方法，不主张算法首创。[同类调查](docs/RESEARCH.md)披露相邻库与成熟外语项目，并说明需要独立求解层的理由。

## 三个完整应用场景

| 使用者/问题 | 输入和操作 | 已验证结果 |
| --- | --- | --- |
| 几何工具开发者求区域内圆线全部交点 | geometry.json：x²+y²−2=0、y−x=0，[-1.5,1.5]² | 两个唯一解盒包含(-1,-1)、(1,1)，无未决 |
| 标定软件开发者处理非单调响应和容差 | calibration.json：x³−3x+1=0先查[-2.5,2.5]，再限[0,1]；另可加入±0.125响应带 | 精确模式3个分支，限范围后1个；全范围观测带得到29个整盒可行盒、12个未决盒，达到0.001分辨率 |
| 定位工具开发者处理有界测量误差 | noisy_localization.json：三个基站距离平方带约束两个坐标，范围[0,2]² | 19个整盒可行盒、40个未决盒，未决宽度达到1/64；(1,1)被保留 |

这些数量是固定示例的结果。可行盒数量不是解的个数；各盒包含连续多个点。观测带是调用者给定的界，不代表统计置信区间或真实传感器精度。所有示例合成，不冒称客户/设备落地。

另保留反应模型稳态、三维测距镜像位置、六元耦合64根及重根反例。每个场景的完整用户、输入、操作、输出和验证见[SCENARIOS](docs/SCENARIOS.md)。

## 在MoonBit中复用

```text
moon add LMK-ai-nb/rootcover@0.2.0
```

在调用包导入 `LMK-ai-nb/rootcover`。完整可执行示例见[API.mbt.md](API.mbt.md)，所有示例随moon test编译执行。

| 接口 | 功能 |
| --- | --- |
| interval / Interval运算 | binary64向外舍入区间 |
| parse_polynomial / validate_system | 明确语法、节点和模型边界 |
| enclose / assess / solve | 方程/Jacobian区间、单盒判定与根域搜索 |
| validate_constraints / classify_constraints / pave | 非方观测带模型、整盒判定和可行域内外包围 |
| decode_request / decode_feasibility_request / solve_json | 严格版本化请求，字符串接口按mode分派 |

省略mode保持0.1版求根行为；新增 `mode:"feasibility"`。拒绝重复解码键、未知字段、非有限数、不支持表达式和资源越界。两类API均不修改输入。

## 正确理解结果

求根：只有Krawczyk映像严格位于盒内部、收缩范数上界<1时才认证唯一性；小残差不是证明。完整分类时root_count表示初始区域内不同实根数；仍有未决时它只表示已确认根数。[求根语义](docs/SEMANTICS.md)。

可行域：每个inside盒的整个区间像均落在所有观测带中，所以盒内所有点满足约束；inside与unresolved联合包围初始域内全部可行点。未决盒不能标成可行或不可行。resolution_met仅描述未决盒宽度，complete单独报告是否仍有未决；不输出root_count。[可行域语义](docs/PAVING.md)。

## 实际验证

```text
python scripts/verify.py --browser
# 具备本机C工具链时：
python scripts/verify.py --native --browser
```

33项MoonBit测试（含3项公开API文档）、13项Node集成。原求根核对：2800组区间、182个已知系统、513份唯一性证据重放。新增可行域核对：37个模型、1310个内包围盒精确重放、4413个有理数网格点覆盖检查。Python Fraction/AST参考不使用本项目的舍入、搜索或求解代码。

Chromium实际测试包括根/容差场景、分支、预算、报告、坏JSON、注入文本、乱序样例响应、取消与390px布局。原始命令/退出码/输出写入artifacts，CI上传验证JSON。有限测试不是全实现形式化证明；本地未配置MSVC，native实际运行以远程CI证据为准。

## 范围

多项式仅支持+、-、*、括号与整数幂0…16，总次数≤32、全模型节点≤512、深度≤32。系数和输入边界按binary64点值解释，观测带是多项式输出约束；不等于系数不确定族、精确十进制、超越函数、复数、全局优化或统计概率。最多20000次评估、搜索深度80。重根、边界、病态和资源限制均可能留下未决。

MIT，标准库许可和NOTICE随分发保留；[来源](THIRD_PARTY_NOTICES.md)。真实工业模型采用、系统规模/病态评测、更高精度后端尚未完成，不列为本轮已具备能力。官方报名和审核结果见规则记录，技术发布不构成通过初审。
