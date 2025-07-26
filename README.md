# 视频预览生成器

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/kkfive/shot-stitch)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](Dockerfile)

一个功能强大的本地视频预览图像生成器，具备智能场景检测、批量处理和 Docker 支持。零配置生成高质量视频缩略图。

> **🚀 最新版本**: 版本 0.4.0 - 并行场景检测，性能提升3-5倍，实时进度监控

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

### 🚀 并行场景检测 (v0.4.0 重大突破)
- **分段并行算法**: 视频分段并行处理，性能提升3-5倍
- **实时进度监控**: `总进度:75% [分段0:✓ | 分段1:✓ | 分段2:60%]`
- **智能分段策略**: 基于CPU核心数动态调整，最多8个分段
- **超时问题解决**: 彻底解决大文件超时失败问题
- **macOS兼容**: 完美支持macOS环境，解决timeout命令问题

### 🎯 分批生成 (v0.3.0 新增)
- **智能分批**: 自动按帧数或尺寸限制分割大型预览图
- **灵活控制**: 支持用户自定义每部分最大帧数
- **强制分批**: 可强制启用分批模式，适合特殊需求

### 📊 性能表现 (v0.4.0)
| 视频规模 | v0.3.0 | v0.4.0 | 提升幅度 |
|---------|--------|--------|----------|
| 2.4GB, 40分钟 | 133秒 | 132秒 | 基准 |
| 5.8GB, 112分钟 | 超时失败 | ~5-8分钟 | **从失败到成功** |
| 10GB+ 大文件 | 超时失败 | ~10-15分钟 | **3-5倍提升** |
- **预设优化**: 各预设模板内置最佳分批参数

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
- **Web预览器**: 内置发布资源预览器，支持图片查看和下载 (v0.3.0)

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

# 分批生成模式 - 每部分最多30帧
./preview.sh video.mp4 --max-frames-per-part 30

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

# 强制分批生成
./preview.sh video.mp4 --force-split --max-frames-per-part 25
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
| `--max-frames-per-part <数量>` | 每部分最大帧数，用于分批生成 | 0 (使用尺寸限制) |
| `--force-split` | 强制启用分批生成模式 | - |
| `--force` | 覆盖现有文件 | - |
| `--help` | 显示帮助信息 | - |

### 🚀 并行场景检测参数 (v0.4.0)

| 配置参数 | 描述 | 默认值 |
|----------|------|--------|
| `SCENE_DETECTION_MAX_SEGMENTS` | 最大分段数，提升大文件处理速度 | 8 |
| `SCENE_DETECTION_SEGMENT_TIMEOUT` | 每段超时时间(秒)，设为0禁用超时 | 0 |

这些参数在预设配置文件中设置，如 `presets/dynamic.conf`：
```bash
# 场景检测优化配置
SCENE_DETECTION_MAX_SEGMENTS=8  # 最大分段数
SCENE_DETECTION_SEGMENT_TIMEOUT=0  # 禁用超时，依赖算法自然完成
```

### 可用预设

| 预设 | 最适合 | 模式 | 关键设置 |
|------|--------|------|----------|
| `movie` | 电影、电视剧 | keyframe | 4 列，60 秒间隔，90% 质量 |
| `lecture` | 讲座、会议 | time | 6 列，120 秒间隔，85% 质量 |
| `quick` | 快速预览 | time | 3 列，300 秒间隔，80% 质量 |
| `dynamic` | 动态内容 | scene | 5 列，15-45 秒间隔，90% 质量，**并行场景检测** |

## 🎛️ 捕获模式

### 时间模式 (默认)
- **最适合**: 通用目的，一致间隔
- **工作原理**: 按固定时间间隔捕获帧
- **使用场景**: 快速预览，均匀采样

### 场景检测模式 (推荐) ⚡ v0.4.0 重大升级
- **最适合**: 有场景变化的动态内容
- **工作原理**: 基于视觉内容变化的智能检测
- **使用场景**: 电影、纪录片、多样化内容
- **性能优化**: 降采样分析，多线程处理，2-5倍性能提升
- **🚀 并行算法**: 分段并行处理，大文件性能提升3-5倍
- **📊 实时监控**: 显示每个分段的处理进度
- **🔧 智能分段**: 基于CPU核心数动态调整分段策略

### 关键帧模式 (高质量)
- **最适合**: 高质量内容，电影
- **工作原理**: 检测并捕获 I 帧 (关键帧)
- **使用场景**: 优质内容，详细分析
- **性能优化**: 自适应算法选择，流式处理，2-45倍性能提升

## 🎯 分批生成详解

### 什么是分批生成
分批生成功能可以将大量截图自动分割成多个较小的预览图文件，避免单个文件过大导致的问题：
- **内存限制**: 避免ImageMagick内存不足
- **文件大小**: 控制单个文件大小，便于分享和查看
- **加载性能**: 提升大型预览图的加载速度

### 分批触发条件
1. **用户强制**: 使用 `--force-split` 参数
2. **帧数限制**: 使用 `--max-frames-per-part` 设置每部分最大帧数
3. **尺寸限制**: 自动检测图像尺寸是否超出格式限制

### 分批参数说明
- `--max-frames-per-part 30`: 每个部分最多30帧
- `--force-split`: 强制启用分批模式
- 设置为0表示使用尺寸限制逻辑（默认行为）

### 分批示例
```bash
# 每部分最多25帧
./preview.sh video.mp4 --max-frames-per-part 25

# 强制分批，使用预设的分批参数
./preview.sh video.mp4 --force-split --preset dynamic

# 结合其他参数使用
./preview.sh video.mp4 --mode scene --max-frames-per-part 20 --column 4
```

## 🌐 Web预览器

### 发布资源预览器
项目内置了一个现代化的Web预览器 (`index.html`)，提供完整的图片查看和管理功能：

#### 核心功能
- **图片查看**: 支持缩放、旋转、全屏查看
- **批量管理**: 支持多选、批量下载
- **格式转换**: 在线转换图片格式
- **响应式设计**: 适配各种设备屏幕

#### 使用方法
1. 将生成的预览图文件放在项目目录中
2. 在浏览器中打开 `index.html`
3. 拖拽或选择图片文件进行查看

#### 技术特性
- **Viewer.js**: 专业图片查看器，支持手势操作
- **StreamSaver.js**: 支持大文件流式下载
- **现代化界面**: 基于CSS Grid和Flexbox的响应式布局
- **无服务器**: 纯前端实现，无需服务器环境

## 🤖 GitHub Actions 工作流

### 自动化截图生成
项目内置了GitHub Actions工作流，支持通过Web界面自动生成视频截图：

#### 功能特性
- **在线处理**: 无需本地环境，直接在GitHub上处理视频
- **灵活配置**: 支持自定义预设模式和目标仓库
- **自动发布**: 生成的截图自动发布到指定仓库的Releases
- **进度跟踪**: 实时显示下载和处理进度

#### 使用方法
1. 在GitHub仓库页面点击 "Actions" 标签
2. 选择 "生成视频截图" 工作流
3. 点击 "Run workflow" 并填写参数：
   - **视频URL**: 要处理的视频文件链接
   - **预设模式**: 选择预设配置（movie/lecture/quick/dynamic）
   - **目标仓库**: 发布截图的仓库（默认：kkfive-action/private-screenshots）
4. 等待工作流完成，在目标仓库的Releases中下载结果

#### 参数说明
- `video_url`: 支持HTTP/HTTPS的视频文件直链
- `preset`: 预设模式，影响截图质量和数量
- `target_repo`: 格式为 `owner/repo-name`，需要有相应的访问权限

> 📖 **详细使用指南**: 查看 [GitHub Actions 使用文档](GITHUB_ACTIONS.md) 了解完整的配置和故障排除信息

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
- **核心特点**: 场景检测模式 + 5列布局 + 15-45秒间隔 + 92%质量
- **优势**: 密集捕获动作变化，确保不遗漏重要场景
- **分批设置**: 每部分最多30帧，适合动态内容的密集截图

## �🏗️ 项目结构

```
shot-stitch/
├── preview.sh              # 主入口点
├── index.html              # Web预览器 (v0.3.0)
├── .github/                # GitHub Actions 工作流
│   └── workflows/
│       └── generate-screenshots.yml  # 自动化截图生成
├── lib/                    # 核心模块
│   ├── core.sh             # 核心功能
│   ├── args.sh             # 参数解析
│   ├── video_info.sh       # 视频信息
│   ├── scene_detect.sh     # 场景检测
│   ├── keyframe.sh         # 关键帧检测
│   ├── parallel.sh         # 并行处理
│   ├── frame_extract.sh    # 帧提取
│   ├── image_process.sh    # 图像处理 (分批生成)
│   ├── html_report.sh      # HTML 报告
│   └── batch_process.sh    # 批量处理
├── presets/                # 配置预设
│   ├── movie.conf          # 电影预设 (含分批配置)
│   ├── lecture.conf        # 讲座预设 (含分批配置)
│   ├── quick.conf          # 快速预设 (含分批配置)
│   └── dynamic.conf        # 动态内容预设 (含分批配置)
├── font/                   # 字体文件
├── README.md               # 本文件
├── CHANGELOG.md            # 更新日志
├── GITHUB_ACTIONS.md       # GitHub Actions 使用指南
└── RELEASE_NOTES_v0.3.0.md # v0.3.0 发布说明
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

### v0.3.0 (2025-07-25) - 分批生成与Web预览器

#### 🎯 重大新增
- **分批生成系统**: 支持按帧数自动分批生成，避免单个文件过大
- **Web预览器**: 内置发布资源预览器，支持图片查看和下载
- **智能分批**: 多种分批触发条件，灵活适应不同需求
- **预设优化**: 所有预设内置最佳分批参数

#### 🔧 功能增强
- **新参数**: `--max-frames-per-part` 控制每部分最大帧数
- **新参数**: `--force-split` 强制启用分批模式
- **预设调整**: Dynamic预设优化为5列布局
- **用户体验**: 更清晰的分批原因提示

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
