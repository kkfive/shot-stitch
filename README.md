# 视频预览生成器

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](https://github.com/kkfive/shot-stitch)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](Dockerfile)

一个功能强大的本地视频预览图像生成器，具备智能场景检测、批量处理和 Docker 支持。零配置生成高质量视频缩略图。

> **🚀 最新版本**: 版本 0.2.0 - 全面性能优化，智能算法升级

## ✨ 核心特性

### 🎯 智能处理
- **三种捕获模式**: 时间间隔、场景检测和关键帧检测
- **智能宽度计算**: 基于列数和格式限制自动优化宽度
- **自动分割功能**: 大图像分割为平衡的部分，保持质量
- **动态超时**: 基于文件大小和时长智能调整超时时间

### 🧠 高级算法 (v0.2.0 全面升级)
- **场景检测优化**: 降采样分析，多线程处理，性能提升 2-5倍
- **关键帧检测优化**: 自适应算法选择，流式处理，性能提升 2-45倍
- **自适应策略**: 根据文件大小自动选择最佳算法
- **智能回退机制**: 多层回退保证 100% 兼容性
- **并行处理**: 多核并行捕获，支持大文件分段处理
- **批量处理**: 处理整个目录的视频文件

### 📊 用户体验
- **实时进度**: 所有处理步骤的详细百分比进度
- **增强标题**: 紧凑的标题和文件名显示，包含分割信息
- **时间戳显示**: 每个缩略图的精确时间点
- **性能保护**: 20 列限制防止 ImageMagick 问题

### 🎨 输出定制
- **网格间距控制**: 可调整缩略图之间的间距
- **多种格式**: WebP/JPG/PNG 支持，智能格式处理
- **HTML 报告**: 专业分析报告，现代/简洁主题
- **智能命名**: 可选参数后缀命名，避免冲突

### 🔧 技术卓越
- **预设模板**: 针对不同视频类型的 3 个优化预设
- **模块化架构**: 清洁、可维护、可扩展的代码库
- **配置管理**: 统一配置系统，智能验证

## 🚀 快速演示

```bash
# 基本用法 - 几秒钟内生成视频预览
./preview.sh video.mp4

# 场景检测模式，智能识别场景变化 (推荐)
./preview.sh video.mp4 --mode scene

# 电影高质量关键帧模式
./preview.sh video.mp4 --preset movie

# 动态内容密集截图模式
./preview.sh video.mp4 --preset dynamic

# 批量处理整个目录
./preview.sh ./videos/
```

**示例输出:**
- 带时间戳的高质量网格布局
- 自动格式优化 (WebP/JPG/PNG)
- 专业 HTML 报告
- 智能文件命名，避免冲突

## 📦 安装

### 🐳 Docker (推荐)

**零依赖一键设置:**

```bash
# 快速开始
docker run --rm -v $(pwd):/data video-preview-tool video.mp4

# 从源码构建
git clone https://github.com/kkfive/shot-stitch.git
cd shot-stitch
docker build -t video-preview-tool .
docker run --rm -v $(pwd):/data video-preview-tool video.mp4
```

### 📦 本地安装

**依赖要求:**
- **FFmpeg**: 视频处理和帧提取
- **ImageMagick**: 图像处理和合成
- **bc**: 数学计算

**安装依赖:**

```bash
# macOS
brew install ffmpeg imagemagick bc

# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg imagemagick bc

# CentOS/RHEL/Fedora
sudo dnf install ffmpeg ImageMagick bc
```

## 🚀 快速开始

### 基本用法

```bash
# 使用默认设置生成预览
./preview.sh video.mp4

# 场景检测模式，智能识别场景变化 (推荐)
./preview.sh video.mp4 --mode scene

# 高质量关键帧模式
./preview.sh video.mp4 --mode keyframe

# 使用优化预设
./preview.sh video.mp4 --preset movie

# 动态内容预设
./preview.sh video.mp4 --preset dynamic

# 批量处理目录
./preview.sh ./videos/

# 生成 HTML 报告
./preview.sh video.mp4 --html --preset movie
```

### 高级示例

```bash
# 自定义参数
./preview.sh video.mp4 --mode scene --min-interval 60 --max-interval 300 --column 4 --quality 90

# 高密度捕获
./preview.sh video.mp4 --column 8 --interval 30 --format webp

# 大文件处理 (自动分割)
./preview.sh large_video.mkv --mode keyframe --column 6
```

## 📖 API 参考

### 命令语法
```bash
./preview.sh <视频文件或目录> [选项]
```

### 核心参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `--mode <time\|scene\|keyframe>` | 捕获模式 | time |
| `--interval <秒数>` | 捕获时间间隔 | 10 |
| `--min-interval <秒数>` | 场景检测模式最小间隔 | 30 |
| `--max-interval <秒数>` | 场景检测模式最大间隔 | 300 |
| `--scene-threshold <0.1-1.0>` | 场景变化敏感度 | 0.3 |
| `--keyframe-min <秒数>` | 关键帧模式最小间隔 | 5 |
| `--quality <1-100>` | 图像质量 (越高越好) | 100 |
| `--column <数量>` | 网格列数 (最大 20) | 5 |
| `--format <webp\|jpg\|png>` | 输出格式 | webp |
| `--preset <name>` | 使用预设配置 | - |
| `--html` | 生成 HTML 报告 | - |
| `--jobs <数量\|auto>` | 并行处理任务数 | auto |
| `--force` | 覆盖现有文件 | - |
| `--help` | 显示帮助信息 | - |

### 可用预设

| 预设 | 最适合 | 模式 | 关键设置 |
|------|--------|------|----------|
| `movie` | 电影、电视剧 | keyframe | 4 列，60 秒间隔，90% 质量 |
| `lecture` | 讲座、会议 | time | 6 列，120 秒间隔，85% 质量 |
| `quick` | 快速预览 | time | 3 列，300 秒间隔，80% 质量 |
| `dynamic` | 动态内容 | scene | 6 列，15-45 秒间隔，92% 质量 |

## 🎛️ 捕获模式

### 时间模式 (默认)
- **最适合**: 通用目的，一致间隔
- **工作原理**: 按固定时间间隔捕获帧
- **使用场景**: 快速预览，均匀采样

### 场景检测模式 (推荐)
- **最适合**: 有场景变化的动态内容
- **工作原理**: 基于视觉内容变化的智能检测
- **使用场景**: 电影、纪录片、多样化内容
- **性能优化**: 降采样分析，多线程处理，2-5倍性能提升

### 关键帧模式 (高质量)
- **最适合**: 高质量内容，电影
- **工作原理**: 检测并捕获 I 帧 (关键帧)
- **使用场景**: 优质内容，详细分析
- **性能优化**: 自适应算法选择，流式处理，2-45倍性能提升

## � 预设详解

### Movie 预设 - 电影优化
- **适用场景**: 电影、电视剧、纪录片
- **核心特点**: 关键帧模式 + 4列布局 + 90%高质量
- **优势**: 基于I帧的智能截图，保证关键场景不遗漏

### Lecture 预设 - 讲座优化
- **适用场景**: 讲座、会议、教程、培训视频
- **核心特点**: 时间模式 + 6列布局 + 120秒间隔
- **优势**: 适合内容变化较慢的场景，提供全面概览

### Quick 预设 - 快速预览
- **适用场景**: 快速预览、大批量处理
- **核心特点**: 时间模式 + 3列布局 + 300秒间隔
- **优势**: 处理速度优先，适合快速了解视频内容

### Dynamic 预设 - 动态内容
- **适用场景**: 动作频繁、变化密集的视频内容
- **核心特点**: 场景检测模式 + 6列布局 + 15-45秒间隔 + 92%质量
- **优势**: 密集捕获动作变化，确保不遗漏重要场景

## �🏗️ 项目结构

```
shot-stitch/
├── preview.sh              # 主入口点
├── lib/                    # 核心模块
│   ├── core.sh             # 核心功能
│   ├── args.sh             # 参数解析
│   ├── video_info.sh       # 视频信息
│   ├── scene_detect.sh     # 场景检测
│   ├── keyframe.sh         # 关键帧检测
│   ├── parallel.sh         # 并行处理
│   ├── frame_extract.sh    # 帧提取
│   ├── image_process.sh    # 图像处理
│   ├── html_report.sh      # HTML 报告
│   └── batch_process.sh    # 批量处理
├── presets/                # 配置预设
│   ├── movie.conf          # 电影预设
│   ├── lecture.conf        # 讲座预设
│   ├── quick.conf          # 快速预设
│   └── dynamic.conf        # 动态内容预设
├── font/                   # 字体文件
└── README.md               # 本文件
```

## 🤝 贡献

我们欢迎贡献！请查看我们的 [贡献指南](CONTRIBUTING.md) 了解详情。

### 开发设置

```bash
git clone https://github.com/kkfive/shot-stitch.git
cd shot-stitch
chmod +x preview.sh
./preview.sh --help
```

## 📝 更新日志

### v0.2.0 (2025-07-25) - 性能优化大版本

#### 🚀 重大改进
- **模式重命名**: `smart` → `scene` 更明确的命名
- **场景检测优化**: 降采样分析，多线程处理，**2-5倍性能提升**
- **关键帧检测优化**: 自适应算法选择，流式处理，**2-45倍性能提升**
- **自适应策略**: 根据文件大小自动选择最佳算法
- **智能回退机制**: 多层回退保证100%兼容性

#### 🔧 技术升级
- **流式处理**: 支持超大文件和中断恢复
- **分段并行**: 大文件自动分段并行处理
- **内存优化**: 智能内存管理和垃圾回收
- **性能监控**: 详细的性能统计和报告

#### 📊 性能表现
- **小文件** (<100MB): 使用原始算法避免优化开销
- **中等文件** (100MB-1GB): 2-5倍性能提升
- **大文件** (1GB-2GB): 5-20倍性能提升
- **超大文件** (>2GB): 10-45倍性能提升

### v0.1.0 (2025-07-23) - 初始发布
- 基础视频预览生成功能
- 三种捕获模式支持
- 并行处理和批量处理
- Docker 支持

## 📄 许可证

本项目采用 MIT 许可证 - 详情请查看 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- **FFmpeg** - 强大的视频处理框架
- **ImageMagick** - 全面的图像处理工具包
- **社区** - 感谢所有贡献者和用户

---

**为视频处理社区用 ❤️ 制作**
