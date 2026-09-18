# 脉络健康 (ChronoCare) - 慢病复查助手 🩺

> 专为慢性病病程管理与复查追踪打造的**高自定义度、本地隐私优先、AI 赋能**移动端软件。

[![Build & Release Android APK](https://github.com/liwo1861a-hub/chronocare-app/actions/workflows/build-release.yml/badge.svg)](https://github.com/liwo1861a-hub/chronocare-app/actions/workflows/build-release.yml)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](assets/version.json)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 🌟 核心特性与设计亮点

### 1. 🤖 默认搭载 Google Gemini 3.7 Flash & 免费 OCR 双引擎
- **默认搭载多模态大模型**：预置接入 `gemini-3.7-flash`，依托 Google 免费层强大的视觉理解能力，一步完成化验单扫描、文字识别、异常判断与结构化分类整理。
- **免费 OCR 服务生态**：集成 OCR.space 免费在线 API 与端侧离线 ML Kit OCR 引擎，零成本即用。
- **全面自定义大模型厂商**：支持切换至 DeepSeek (V3/R1)、OpenAI (GPT-4o)、Claude 以及自定义兼容 OpenAI 协议的任何中转或本地服务（Ollama、硅基流动等）。

### 2. ⚡ 批量导入与双独立自动化开关
在批量扫单页面，设置了两个核心自动化开关：
- 🔘 **开关 1【批量上传后自动 OCR 识别】**：支持一次性导入 1~50 张化验单图片，后台自动排队执行 OCR 文字提取。
- 🔘 **开关 2【OCR 完成后自动 AI 整理分类】**：自动调用 Gemini 3.7 Flash，将化验单自动拆解为：**检验项目、数值、单位、参考区间、异常标记（↑/↓/阳性）、检查日期、医院科室、医生医嘱**，并自动打标签归类。

### 3. 📈 核心检验指标历史横向对比与动态走势图
- **单指标走势折线图**：动态渲染历史指标曲线，叠加正常参考范围带与个人目标线。
- **多节点横向对比表**：直观展示历次复查指标数值变化幅度与升降箭头（如 `7.2 ↑ (+0.8)`）。

### 4. 🎛️ 极致高度自定义 & 【高级功能】专区
- **设置-高级功能**：
  - OCR 引擎细粒度选择与图像去噪增强开关；
  - AI 大模型参数（Temperature、MaxTokens、自定义 System Prompt）；
  - 生物特征（指纹/面容）隐私锁与调试日志；
- **全软件可配置**：疾病分类、病程分期、参考值体系、多处备注、多栏目自定义开关与排序、主题色个性化。

### 5. ☁️ WebDAV 自动定时同步与本地 ZIP 备份
- **WebDAV 支持**：无缝对接坚果云、Nextcloud、群晖 NAS、AList 等。
- **自动同步策略**：支持 App 启动时自动拉取、每日固定时间自动静默同步。
- **本地完整备份**：一键导出包含全部 JSON 数据与化验单照片原图的 `.zip` 备份文件，支持随时还原。

### 6. 🔄 固定签名与 App 内一键检查更新
- **固定签名机制**：CI/CD 自动化构建内置固定 Keystore，保证每次升级版本签名一致，覆盖安装零冲突。
- **App 内就地更新**：自动检测 GitHub 最新 Release，App 内置多线程下载器并自动唤起安装。

---

## 📱 软件截图与多栏目架构

| 📅 时间轴视图 | 🏷️ 慢病病程档案 | 🔬 检查项目分类 | 📈 核心指标走势 |
| :---: | :---: | :---: | :---: |
| 历次复查卡片汇总 | 疾病分期与控制目标 | 血液/影像/超声大类 | 动态折线与历史矩阵 |

---

## 🛠️ 构建与编译 (Build & CI/CD)

项目通过 GitHub Actions 全自动构建发布，提交代码至 `main` 分支或推送标签 `v*` 即可自动触发生成 release APK。

```bash
# 本地测试与构建
flutter pub get
flutter run
flutter build apk --release
```

---

## 📄 开源许可证

本项目遵循 MIT 开源协议。
