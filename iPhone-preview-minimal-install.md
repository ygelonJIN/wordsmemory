# 只做 iPhone 预览的最小安装清单

这个项目是 Flutter 项目。若你现在只想做 iPhone 预览，先只装下面这些就够了。

## 1. Homebrew
用于安装和管理命令行工具。

安装命令：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装后建议检查：

```bash
brew --version
```

## 2. FVM
FVM 只管理 Flutter 版本，适合避免不同项目互相影响。

安装命令：

```bash
brew tap leoafarias/fvm
brew install fvm
```

检查：

```bash
fvm --version
```

## 3. Flutter SDK
用 FVM 安装 Flutter，不建议直接全局乱装。

进入项目后：

```bash
fvm install
fvm flutter pub get
```

如果项目里没有指定版本，先用稳定版也可以。

## 4. Xcode
iPhone 真机和模拟器预览都需要。

安装后建议执行：

```bash
sudo xcodebuild -runFirstLaunch
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 5. CocoaPods
Flutter 的 iOS 依赖常用到。

安装命令：

```bash
brew install cocoapods
```

检查：

```bash
pod --version
```

## 6. 你现在可以先不装的东西
如果只做 iPhone 预览，可以先不装：

- Android Studio
- Android SDK
- 安卓模拟器
- Docker / container 相关工具

## 7. iPhone 预览方式
### 模拟器

```bash
fvm flutter run -d ios
```

### 真机

- iPhone 用数据线连接 Mac
- 手机上点信任此电脑
- 在 Xcode 中完成签名设置
- 然后运行：

```bash
fvm flutter run -d ios
```

## 8. 最小执行顺序

1. 安装 Homebrew
2. 安装 FVM
3. 安装 Xcode
4. 安装 CocoaPods
5. 在项目里执行 `fvm install`
6. 执行 `fvm flutter pub get`
7. 执行 `fvm flutter run -d ios`

## 9. 说明

这个项目当前是 Flutter 项目，所以 iPhone 预览走的是 Flutter 的 iOS 路线，不需要先装 Android 相关环境。
