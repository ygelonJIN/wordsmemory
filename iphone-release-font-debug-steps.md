# iPhone 中文字体 release 问题排查步骤

1. 先确认问题只在 `release` 出现。分别跑 `debug`、`profile`、`release`，看同一段中文 `fontWeight` 是否变化。
2. 用最小测试验证。只保留一行中文和 `fontWeight: w100 / w400 / w600 / w900`，不要带页面主题和复杂布局。
3. 换 Flutter 版本测试。优先对比当前版本和上一个稳定版，看问题是不是版本回归。
4. 如果只有 `release` 异常，先别继续改字体方案，优先怀疑 Flutter / iOS 渲染链路。
5. 把结论记录下来：`debug` 是否正常、`profile` 是否正常、`release` 是否异常、哪个 Flutter 版本正常。
