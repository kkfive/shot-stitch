# Shot Stitch v0.3.0 发布说明

## 🎯 版本亮点

### 分批生成系统
v0.3.0 引入了全新的分批生成功能，解决大量截图时的文件大小和性能问题：

- **智能分批**: 自动检测并分割大型预览图
- **灵活控制**: 用户可自定义每部分最大帧数
- **多种触发**: 支持强制分批、帧数限制、尺寸限制等多种模式
- **预设优化**: 所有预设模板内置最佳分批参数

### Web预览器
新增现代化的Web预览器，提供完整的图片管理功能：

- **专业查看**: 基于Viewer.js的图片查看器
- **批量操作**: 支持多选、批量下载、格式转换
- **响应式设计**: 适配各种设备和屏幕尺寸
- **无服务器**: 纯前端实现，开箱即用

## 🔧 新增功能

### 命令行参数
- `--max-frames-per-part <数量>`: 设置每部分最大帧数
- `--force-split`: 强制启用分批生成模式

### 预设优化
- **Movie预设**: 每部分最多40帧，适合电影长片
- **Lecture预设**: 每部分最多30帧，适合讲座视频
- **Dynamic预设**: 每部分最多30帧，列数优化为5列
- **Quick预设**: 使用尺寸限制逻辑，保持快速处理

## 📈 使用示例

### 分批生成
```bash
# 每部分最多25帧
./preview.sh video.mp4 --max-frames-per-part 25

# 强制分批模式
./preview.sh video.mp4 --force-split

# 结合预设使用
./preview.sh video.mp4 --preset dynamic --max-frames-per-part 20
```

### Web预览器
1. 生成预览图后，在浏览器中打开 `index.html`
2. 拖拽或选择图片文件进行查看
3. 使用工具栏进行缩放、旋转、下载等操作

## 🔄 升级指南

### 从 v0.2.0 升级
1. 所有现有命令保持兼容，无需修改
2. 新功能为可选功能，不影响现有工作流
3. 预设配置自动包含分批参数，无需手动配置

### 推荐设置
- **大文件处理**: 使用 `--max-frames-per-part 30` 控制文件大小
- **批量处理**: 结合 `--force-split` 确保一致的输出格式
- **Web查看**: 使用内置的 `index.html` 预览器管理生成的图片

## 🐛 已知问题

- 分批生成时，每个部分的文件名会包含序号后缀
- Web预览器需要现代浏览器支持（Chrome 60+, Firefox 55+, Safari 12+）

## 📋 完整更新日志

详细的更新内容请查看 [CHANGELOG.md](CHANGELOG.md)

## 🙏 致谢

感谢社区用户的反馈和建议，特别是对大文件处理和用户体验方面的改进建议。

---

**下载地址**: [GitHub Releases](https://github.com/kkfive/shot-stitch/releases/tag/v0.3.0)
**文档**: [README.md](README.md)
**问题反馈**: [GitHub Issues](https://github.com/kkfive/shot-stitch/issues)
