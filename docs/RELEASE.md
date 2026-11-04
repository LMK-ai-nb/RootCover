# RootCover 实际发布记录

## 当前版本0.2.0（2026-11-04）

本轮补充带容差观测的连续可行域求解、非方约束、整盒可行证据与未决外包围，保留原有区域求根。三场景已实际覆盖几何交点、非单调标定/观测容差和有界误差定位；不把可行盒数量当作根数。

- [源码提交fbd9c7c](https://github.com/LMK-ai-nb/RootCover/commit/fbd9c7c11845d416dec10ad151e295d0d7dc7439) 的[CI 41842581871](https://github.com/LMK-ai-nb/RootCover/actions/runs/41842581871) 已成功。Windows、macOS、Linux逐一运行wasm、wasm-gc、js、native的严格check/test/build；每个目标33项MoonBit测试全部通过。13项CLI集成、两套独立数值核对与真实打包检查在三平台成功，Linux真实Chromium成功。
- 实际下载三平台的CI artifacts核对：2800组区间运算、182个已知系统、513份唯一性证据重放；新增37个观测带系统、1310份整盒可行证据重放、4413个有理数网格点检查。有限测试不是形式化证明。
- 同一源码的[Pages部署41842581927](https://github.com/LMK-ai-nb/RootCover/actions/runs/41842581927) 已成功；在线工作台入口仍为 https://lmk-ai-nb.github.io/RootCover/ 。实际通过公开URL的Chromium核对：页面版本0.2.0、几何两根和定位19个可行盒/40个未决盒。
- 核实 `moon whoami` 为LMK-ai-nb后，实际 `moon publish` 返回 **200 OK**、退出0；[Mooncakes 0.2.0](https://mooncakes.io/docs/LMK-ai-nb/rootcover@0.2.0) 已发布，未覆盖0.1.0。
- 独立消费工程从公开注册表实际下载0.2.0，无本地路径替代。严格全目标check与Wasm-GC、JS运行成功，断言求根、预算覆盖、整盒可行证据及不修改输入。八个核心MoonBit文件与本地源码逐字节匹配。
- 发布前扫描真实Moon包（72文件）通过，私人报名材料、联系方式、凭据与缓存不在包内。0.2.0包文档是发布时快照，事后验证以GitHub本文和evidence/release-0.2.0.json为准。

```text
moon add LMK-ai-nb/rootcover@0.2.0
```

这证明工程已经运行、发布和被独立下载；不代表报名成功、初审通过或获奖。完整旧版发布记录保留如下。

## 历史版本0.1.0

维护者、参赛者及发布账户：**李明坤 / LMK-ai-nb**。核对时间：2026-11-04，北京时间。

## 已公开入口

- [GitHub仓库](https://github.com/LMK-ai-nb/RootCover)，公开，实际默认分支main。
- [在线工作台](https://lmk-ai-nb.github.io/RootCover/)，GitHub Pages已实际部署。
- [Mooncakes 0.1.0](https://mooncakes.io/docs/LMK-ai-nb/rootcover@0.1.0)。

## 已成功的远程工程验证

[CI运行41817088280](https://github.com/LMK-ai-nb/RootCover/actions/runs/41817088280) 对应源码提交 `7198efa341951469b9c75ad23ce93daafd6a7572`。Windows、macOS、Linux三作业全部成功，各运行wasm、wasm-gc、js、native的严格check/test/build；每个目标24项测试全部通过。另覆盖格式、接口快照、typed demo、9项CLI、独立Fraction oracle、真实打包检查；Linux还运行实际Chromium回归。各作业上传validation/oracle/package-check JSON。

实际远程工具链为moon 0.1.20261102 / moonc 0.10.19+bee578715；本地额外验证0.10.17+093cb8f9c，兼容两者。前序失败记录保留：旧派生语法、新旧标准库JSON类型路径变化、浏览器异步样例竞争均已修复，没有关闭严格检查或通过随意等待掩盖问题。

[Pages部署41817088080](https://github.com/LMK-ai-nb/RootCover/actions/runs/41817088080) 的build/deploy成功。工作台已通过本地和公开URL的真实浏览器核对。

## 发布和消费

`moon whoami`已核实LMK-ai-nb。实际 `moon publish` 返回服务器 **200 OK**，CLI退出0；官方版本页真实显示0.1.0、公开接口和README。发布前真实zip内容扫描通过，联系方式、work、deliverables和缓存均不在包中。

```text
moon add LMK-ai-nb/rootcover@0.1.0
```

在独立消费工程、全新Moon home和空模块缓存下，实际日志观察到 `Downloading LMK-ai-nb/rootcover@0.1.0`。注册表最初完整克隆成功；再次moon update曾遇网络错误，随后对同一公开索引git fetch并fast-forward，取得官方新版本条目。没有通过本地源码路径依赖代替下载。

消费工程 `moon check --target all --deny-warn` 通过，Wasm-GC和JS分别运行并实际输出：

```text
Fresh Mooncakes consumer OK: two root enclosures, unresolved coverage under budget, source unchanged.
```

消费断言两条根包围、预算限制时保留两个未决区域、原始输入未被修改。下载模块中的interval/polynomial/krawczyk/solver/parser/format六个核心文件与工作源码逐字节一致。版本0.1.0是发布时的不可变文档快照；事后发布证明以GitHub当前本文为准。

源码/演示分发包含MIT与标准库许可证和NOTICE，不包含凭据、私人报名资料或本机工具链。官方报名、诚信确认未代执行；没有已经通过初审、验收或获奖的结论。
