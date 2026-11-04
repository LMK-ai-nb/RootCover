# 三个完整可运行场景

全部输入是合成模型，未冒称真实客户或工业采用。核心由同一MoonBit库执行。

| 场景 | 使用者与问题 | 输入 | 操作 | 预期输出 | 验证 |
| --- | --- | --- | --- | --- | --- |
| 几何交点 | 几何工具开发者需要知道一个区域内有哪些圆线交点 | x²+y²−2=0，y−x=0，[-1.5,1.5]² | 执行geometry.json或网页场景01 | 两个唯一解区域分别包含(-1,-1)、(1,1)，complete=true，未决0 | MoonBit、Node、浏览器 |
| 逆向标定 | 标定软件开发者处理非单调响应，避免仅得到一个初值附近的分支 | x³−3x+1=0，[-2.5,2.5] | 执行calibration.json；再改box为[[0,1]]或点击网页分支按钮 | 先3个根，约-1.8793852416、0.3472963553、1.5320888862；再仅1个，complete=true | Node分支断言、浏览器、导出报告中的实际范围 |
| 反应平衡 | 科学模型开发者求指定正区域的稳态 | 1−4x+x²y=0，3x−x²y=0；x∈[0.1,2]，y∈[0.1,6] | 执行equilibrium.json或网页场景03 | 一个唯一解区域包含(1,3)，未决0 | Node、浏览器、解析代入 |

```text
node scripts/build.mjs
node bin/rootcover.mjs examples/geometry.json
node bin/rootcover.mjs examples/calibration.json
node bin/rootcover.mjs examples/equilibrium.json
node --test tests/cli.test.mjs
```

反应示例只表示两个给定多项式平衡方程的零点，不证明模型对应真实工艺、物理稳定性或时间动态。

补充边界：`singular.json` 的x²=0输出包含0的未决盒，退出码1。将几何请求的options.max_assessments设为1，输出2个未决子盒；不能用当前已认证根数推断没有其他根。网页“体验预算耗尽”会把这项修改直接写入JSON。
