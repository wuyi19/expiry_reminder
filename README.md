# 保质期提醒应用

这是一个使用 Flutter 开发的保质期提醒应用，帮助用户管理商品的保质期，避免过期浪费。

## 功能特点

- 添加、编辑和删除商品
- 设置生产日期和保质期
- 自动计算过期日期
- 过期提醒（提前30天、7天和1天）
- 按过期时间或名称排序
- 直观的状态显示（使用不同颜色标识）
- 支持 Android 和 iOS 平台

## 开发环境要求

- Flutter SDK
- Android Studio 或 VS Code
- Android SDK（用于 Android 开发）
- Xcode（用于 iOS 开发，仅 macOS）

## 依赖项

- flutter_local_notifications: ^13.0.0
- sqflite: ^2.2.8+4
- path: ^1.8.3
- intl: ^0.18.0

## 安装步骤

1. 确保已安装 Flutter SDK 并配置好环境
2. 克隆项目到本地
3. 在项目根目录运行 `flutter pub get` 安装依赖
4. 运行 `flutter run` 启动应用

## 使用说明

1. 点击右下角的"添加商品"按钮添加新商品
2. 输入商品名称、选择生产日期、设置保质期
3. 保存后可在主页查看商品列表
4. 点击编辑或删除按钮管理已添加的商品
5. 点击排序按钮可按过期时间或名称排序
6. 商品接近过期时会收到通知提醒

## 注意事项

- 首次使用需要授予通知权限
- 建议定期检查和更新商品信息
- 过期提醒基于系统时间，请确保系统时间准确
- 
