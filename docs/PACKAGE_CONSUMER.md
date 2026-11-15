# 真实打包文件的独立消费检查

0.5.0维护新增（记录形成于dev.2阶段）。此检查不执行publish，也不冒充从Mooncakes下载了新版。

```text
python scripts/consumer_check.py
# 已安装本机C工具链时：
python scripts/consumer_check.py --native
```

脚本实际调用`moon package --list`生成ZIP，检查归档并解压到独立的work临时目录；将tests/consumer的使用工程复制到另一个目录，通过moon.work只指向解压后的库。它不把开发仓库原目录作为库依赖，也不拿旧0.2包替代新版。

消费工程进行全目标严格check、格式检查，以及wasm/wasm-gc/js的实际测试；--native另运行native。每个执行目标5项，分别覆盖：

1. 通过公开类型化API求exp(x)=2、核对唯一根证书，并检查调用未修改输入。
2. 使用非方观测带模型，检查已知可行参数和内盒的区间证据。
3. 组合至少两条观测成立，保留共同区间，排除不满足阈值的另一分支。
4. 从外部模块创建不透明会话、保存、核验恢复和累计推进，并捕获公开错误类型。
5. 从外部模块读取log的定义域状态，区分处处未定义与正常区间。

原始命令、退出码和包SHA256保存在artifacts/package-consumer.json，失败也会留下记录。CI在三平台的完整检查中运行此项并上传结果。使用方不需要Python数值库、Julia或浏览器运行这些MoonBit接口。

moon.work覆盖模块依赖的方式依据[MoonBit模块配置](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#dependency-management)。这是本地分发验证，不是注册表发布/下载证据；新版Mooncakes发布仍按用户要求暂停。
