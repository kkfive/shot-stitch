# 视频预览生成器贡献指南

感谢您对视频预览生成器项目的关注！本文档为贡献者提供指南和信息。

## 🚀 快速开始

### 前置要求
- Bash shell 环境
- 已安装 FFmpeg
- 已安装 ImageMagick
- 已安装 bc (基础计算器)
- Git 版本控制

### 开发设置

1. **Fork 并克隆仓库**
   ```bash
   git clone https://github.com/your-username/shot-stitch.git
   cd shot-stitch
   ```

2. **使脚本可执行**
   ```bash
   chmod +x preview.sh
   ```

3. **测试安装**
   ```bash
   ./preview.sh --help
   ```

## 📋 如何贡献

### 报告问题
- 使用 GitHub issue 跟踪器
- 提供清晰、详细的描述
- 包含系统信息 (操作系统、shell 版本、依赖版本)
- 添加能重现问题的示例视频或命令

### 建议功能
- 创建带有 "enhancement" 标签的 issue
- 描述使用场景和预期行为
- 考虑向后兼容性

### 代码贡献

1. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **进行更改**
   - 遵循现有代码风格
   - 为复杂逻辑添加注释
   - 如需要请更新文档

3. **测试您的更改**
   - 测试各种视频格式
   - 测试所有三种捕获模式
   - 测试批量处理
   - 验证 Docker 功能

4. **提交您的更改**
   ```bash
   git commit -m "Add: brief description of your changes"
   ```

5. **推送并创建拉取请求**
   ```bash
   git push origin feature/your-feature-name
   ```

## 🏗️ 项目结构

```
shot-stitch/
├── preview.sh              # 主入口点
├── lib/                    # 核心模块
│   ├── core.sh             # 核心功能和工具
│   ├── args.sh             # 参数解析和验证
│   ├── video_info.sh       # 视频信息提取
│   ├── scene_detect.sh     # 场景检测算法
│   ├── keyframe.sh         # 关键帧检测
│   ├── parallel.sh         # 并行处理
│   ├── frame_extract.sh    # 帧提取
│   ├── image_process.sh    # 图像处理和合成
│   ├── html_report.sh      # HTML 报告生成
│   └── batch_process.sh    # 批量处理逻辑
├── presets/                # 配置预设
├── font/                   # 字体文件
└── tests/                  # 测试文件和固件
```

## 📝 编码指南

### Shell 脚本最佳实践
- 使用 `#!/bin/bash` shebang
- 引用变量: `"$variable"`
- 函数变量使用 `local`
- 检查命令退出码
- 提供有意义的错误消息
- 使用一致的缩进 (4 个空格)

### 函数命名
- 使用描述性名称: `extract_video_frames`
- 函数使用 snake_case
- 工具函数前缀下划线: `_check_dependencies`

### 错误处理
- 始终检查关键命令退出码
- 使用 `error_exit` 函数处理致命错误
- 提供有用的错误消息和建议

### 文档
- 为复杂算法添加注释
- 记录函数参数和返回值
- 为新功能更新 README
- 包含使用示例

## 🧪 测试

### 手动测试
- 测试各种视频格式 (MP4, AVI, MKV 等)
- 测试所有捕获模式 (时间、智能、关键帧)
- 测试不同参数组合
- 测试多文件批量处理
- 测试 Docker 功能

### 需要覆盖的测试用例
- 短视频 (<1 分钟)
- 长视频 (>1 小时)
- 高分辨率视频 (4K+)
- 低分辨率视频
- 有场景变化的视频
- 静态内容视频
- 损坏或无效文件

## 📦 发布流程

### 版本编号
我们遵循 [语义化版本](https://semver.org/):
- MAJOR.MINOR.PATCH (例如, 1.0.0)
- MAJOR: 破坏性更改
- MINOR: 新功能 (向后兼容)
- PATCH: 错误修复 (向后兼容)

### 发布检查清单
- [ ] 更新 `preview.sh` 中的版本
- [ ] 更新 `Dockerfile` 中的版本
- [ ] 更新 `CHANGELOG.md`
- [ ] 测试所有功能
- [ ] 更新文档
- [ ] 创建发布标签
- [ ] 构建和测试 Docker 镜像

## 🤝 社区指南

### 行为准则
- 保持尊重和包容
- 专注于建设性反馈
- 帮助新手学习和贡献
- 保持专业语调

### 沟通
- 使用清晰、简洁的语言
- 为您的贡献提供上下文
- 如有不清楚的地方请提问
- 分享知识和最佳实践

## 📄 许可证

通过为本项目贡献，您同意您的贡献将在 MIT 许可证下授权。

## 🙏 认可

贡献者将在以下地方得到认可:
- README 致谢
- 发布说明
- 项目文档

感谢您帮助改进视频预览生成器！
