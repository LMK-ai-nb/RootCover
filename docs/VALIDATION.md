# 实际验证

## 历史0.1基线

本地Windows，moonc 0.10.17+093cb8f9c / moon 0.1.20261021，Node22+、Python3.13。真实命令记录在本地artifacts/validation.json，独立核对在artifacts/oracle.json。

执行 `python scripts/verify.py --browser`，覆盖全目标静态检查、wasm/wasm-gc/js三目标的测试和构建、格式、公开接口、typed demo、JS桥接、CLI、精确有理数oracle、真实发布归档和Chromium。24项MoonBit测试（含API文档）、9项Node集成、2800组区间运算、182个解析已知模型、513份唯一性证据重放通过。浏览器检查三场景、分支、预算、下载、原始重复JSON键、注入文本与390px布局。

最初独立核对发现对称分割把某些简单根放在接口，造成保守未决；实现改用确定性非对称分割，并加入三维8根回归。没有通过删除失败输入或伪造完成标记掩盖该问题。边界根和重根仍如实保留未决。

本机缺MSVC/Windows SDK，因此本地native实际构建/运行尚未验证；远程三操作系统、四目标CI的实际状态另见RELEASE.md。不把静态check或workflow文件视为native成功证据。

Fraction/AST oracle是独立后端：从输出域和预条件器重算精确有理数区间Krawczyk映像与范数界；解析模型另验证根数与最终包围。它是有限验证，不是全实现形式化证明。示例全是合成，尚无真实用户/大型工业模型采用证据。

远程Linux浏览器复查还发现异步切换样例时，迟到的响应可能覆盖新输入。界面现按加载编号只接受最新响应，加载/求解时锁定编辑并支持停止；增加可控延迟响应的回归，不以任意等待掩盖竞争。CI上传逐命令验证与oracle报告供核对。

远程最终成功记录：CI 41817088280，源码7198efa，三平台四目标每个24项MoonBit测试全通过；Linux实际浏览器通过，三平台证据JSON均已上传。Mooncakes独立下载安装Wasm-GC/JS通过，核心六文件匹配。

## 0.2 新增能力的验证

本轮增加观测带可行域：33项MoonBit（含3项公开文档）、13项CLI；原根域核对2800/182/513保留。新独立核对37模型、1310个内包围盒、4413个有理数网格点，通过整盒证据、域内包含、正体积不重叠、叶数守恒和可行样本覆盖检查。两套参考使用独立Fraction/AST，不调用工程求解实现来生成预期结果。

真实Chromium新增测距观测带、标定容差、可行/未决分色、导出、迟到响应和加载取消。0.2的[CI 41842581871](https://github.com/LMK-ai-nb/RootCover/actions/runs/41842581871) 已成功，三平台实际运行四目标，每目标33项测试；三平台CI artifacts均已下载核对。Mooncakes0.2.0发布200，独立消费工程真实下载并运行Wasm-GC/JS，八个核心文件字节匹配。具体证据见RELEASE.md与evidence/release-0.2.0.json。
