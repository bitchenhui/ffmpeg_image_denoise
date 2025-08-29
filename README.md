# FFmpeg图像降噪算法比较脚本

这是一个用于测试和比较FFmpeg中5种主要图像降噪算法的脚本工具集，支持参数调整、预设配置和性能比较。

## 功能特性

- 🎯 **5种降噪算法支持**：ATADenoise、VagueDenoiser、FFTdnoiz、OWDenoise、DCTdnoiz
- ⚙️ **灵活参数调整**：每种算法的所有参数都可以自定义
- 📋 **预设配置系统**：内置多种场景的优化参数组合
- 📊 **性能比较报告**：自动生成处理时间和文件大小对比
- 🎨 **彩色输出界面**：友好的用户交互体验
- 📁 **批量处理支持**：可处理多个文件或使用不同预设

## 文件说明

- `denoise_comparison.sh` - 基础版本脚本
- `denoise_advanced.sh` - 高级版本脚本（推荐使用）
- `denoise_presets.conf` - 预设配置文件
- `README.md` - 使用说明文档

## 系统要求

- **操作系统**：Linux、macOS、Windows (WSL)
- **FFmpeg**：版本 4.0 或更高
- **Bash**：版本 4.0 或更高（支持关联数组）
- **可选依赖**：`jq`（用于JSON解析）、`ffprobe`（用于文件信息）

## 安装步骤

1. **克隆或下载脚本文件**
   ```bash
   git clone <repository_url>
   cd ffmpeg-denoise-scripts
   ```

2. **设置执行权限**
   ```bash
   chmod +x denoise_comparison.sh
   chmod +x denoise_advanced.sh
   ```

3. **安装FFmpeg**（如果尚未安装）
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install ffmpeg
   
   # macOS
   brew install ffmpeg
   
   # CentOS/RHEL
   sudo yum install ffmpeg
   ```

## 使用方法

### 基础用法

```bash
# 使用所有算法处理图像
./denoise_advanced.sh input.jpg

# 使用特定算法
./denoise_advanced.sh -a atadenoise input.jpg

# 使用预设参数
./denoise_advanced.sh -P medium_denoise input.jpg

# 自定义参数
./denoise_advanced.sh -p 'atadenoise:0a=0.05:0b=0.08' input.jpg
```

### 高级用法

```bash
# 比较模式，生成性能报告
./denoise_advanced.sh -C input.jpg

# 详细输出模式
./denoise_advanced.sh -v input.jpg

# 指定输出目录和格式
./denoise_advanced.sh -o output_dir -f mp4 input.jpg

# 列出所有可用预设
./denoise_advanced.sh -l

# 使用自定义配置文件
./denoise_advanced.sh -c my_presets.conf -P custom_preset input.jpg
```

## 支持的算法

### 1. ATADenoise（自适应时间平均降噪器）
- **适用场景**：时间相关的视频噪声、摄像机抖动
- **主要参数**：
  - `0a`, `1a`, `2a`：各平面阈值A（0-0.3）
  - `0b`, `1b`, `2b`：各平面阈值B（0-5.0）
  - `s`：用于平均的帧数（5-129，必须为奇数）
  - `algorithm`：算法变体（p=并行，s=串行）

### 2. VagueDenoiser（小波降噪器）
- **适用场景**：各种类型的图像噪声，平衡效果和速度
- **主要参数**：
  - `threshold`：过滤强度（0-∞）
  - `method`：过滤方法（hard/soft/garrote）
  - `nsteps`：小波分解步数（1-32）
  - `percent`：完全降噪百分比（0-100）

### 3. FFTdnoiz（3D FFT降噪器）
- **适用场景**：需要精确频域控制的场景
- **主要参数**：
  - `sigma`：噪声sigma常数（0-30）
  - `amount`：降噪量（0.01-1.0）
  - `block`：块大小（8-256）
  - `overlap`：块重叠（0.2-0.8）

### 4. OWDenoise（过完备小波降噪器）
- **适用场景**：需要分别控制亮度和色度降噪
- **主要参数**：
  - `depth`：位深度（8-16）
  - `luma_strength`：亮度强度（0-1000）
  - `chroma_strength`：色度强度（0-1000）

### 5. DCTdnoiz（DCT域降噪器）
- **适用场景**：块状噪声、需要自定义处理的场景
- **主要参数**：
  - `sigma`：噪声阈值
  - `overlap`：块重叠
  - `n`：块大小（1<<n）

## 预设配置

### 内置预设

| 预设名称 | 描述 | 适用场景 |
|---------|------|----------|
| `light_denoise` | 轻度降噪 | 轻微噪声，保持细节 |
| `medium_denoise` | 中度降噪 | 中等噪声，平衡效果 |
| `strong_denoise` | 强度降噪 | 严重噪声，最大降噪 |
| `video_denoise` | 视频降噪 | 视频序列优化 |
| `fast_denoise` | 快速降噪 | 实时处理需求 |
| `high_quality_denoise` | 高质量降噪 | 高质量输出要求 |

### 特定噪声类型预设

| 预设名称 | 描述 | 适用噪声类型 |
|---------|------|-------------|
| `gaussian_noise` | 高斯噪声降噪 | 高斯分布噪声 |
| `salt_pepper_noise` | 椒盐噪声降噪 | 椒盐噪声 |
| `compression_noise` | 压缩伪影降噪 | 压缩伪影 |

## 参数调整指南

### 轻度降噪（保持细节）
```bash
# ATADenoise
-p 'atadenoise:0a=0.01:0b=0.02:s=5'

# VagueDenoiser
-p 'vaguedenoiser:threshold=1.0:method=soft:percent=60'

# FFTdnoiz
-p 'fftdnoiz:sigma=0.5:amount=0.7:block=16'
```

### 强度降噪（最大效果）
```bash
# ATADenoise
-p 'atadenoise:0a=0.05:0b=0.10:s=15:algorithm=s'

# VagueDenoiser
-p 'vaguedenoiser:threshold=4.0:method=hard:percent=95'

# FFTdnoiz
-p 'fftdnoiz:sigma=3.0:amount=1.0:block=64:overlap=0.7'
```

### 快速处理（实时需求）
```bash
# ATADenoise
-p 'atadenoise:s=5:algorithm=p'

# VagueDenoiser
-p 'vaguedenoiser:nsteps=4:method=hard'

# FFTdnoiz
-p 'fftdnoiz:block=16:overlap=0.2'
```

## 输出文件命名

脚本会自动为输出文件添加算法标识：

```
input.jpg → input_atadenoise.mp4
input.jpg → input_vaguedenoiser.mp4
input.jpg → input_fftdnoiz.mp4
input.jpg → input_owdenoise.mp4
input.jpg → input_dctdnoiz.mp4
```

## 性能比较报告

启用比较模式（`-C`）后，脚本会生成详细的性能报告：

```
FFmpeg图像降噪算法比较报告
================================
输入文件: input.jpg
生成时间: 2024-01-01 12:00:00
输出目录: denoised_output

算法性能比较:
--------------------------------
算法                 处理时间(秒)    输出文件大小
--------------------------------
atadenoise          15             2.5M
vaguedenoiser       25             2.8M
fftdnoiz            45             3.2M
owdenoise           20             2.6M
dctdnoiz            30             2.9M

建议:
--------------------------------
1. 处理时间最短: atadenoise (15秒)
2. 输出文件最小: atadenoise: 2.5M
3. 质量/速度平衡: vaguedenoiser (推荐用于一般用途)
```

## 故障排除

### 常见问题

1. **FFmpeg未找到**
   ```bash
   错误: 未找到ffmpeg命令
   解决: 安装FFmpeg或确保在PATH中
   ```

2. **配置文件不存在**
   ```bash
   错误: 配置文件不存在: denoise_presets.conf
   解决: 确保配置文件在正确位置
   ```

3. **参数格式错误**
   ```bash
   错误: 不支持的算法 'unknown'
   解决: 检查算法名称拼写
   ```

4. **内存不足**
   ```bash
   解决: 减少块大小或使用更快的算法
   ```

### 性能优化建议

1. **大文件处理**：使用较小的块大小和重叠
2. **实时需求**：选择ATADenoise或VagueDenoiser
3. **质量优先**：使用VagueDenoiser的garrote方法
4. **内存限制**：避免使用过大的FFT块大小

## 高级配置

### 自定义预设

在`denoise_presets.conf`中添加新预设：

```ini
[my_custom_preset]
# ATADenoise参数
atadenoise.0a = 0.03
atadenoise.0b = 0.06
atadenoise.s = 11

# VagueDenoiser参数
vaguedenoiser.threshold = 2.5
vaguedenoiser.method = garrote
vaguedenoiser.percent = 80
```

### 批量处理

创建批量处理脚本：

```bash
#!/bin/bash
for file in *.jpg; do
    ./denoise_advanced.sh -P medium_denoise "$file"
done
```

## 贡献和反馈

欢迎提交问题报告、功能请求或代码贡献！

## 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持5种主要降噪算法
- 基础参数调整功能

### v1.1.0
- 添加预设配置系统
- 支持性能比较报告
- 增强的错误处理

### v1.2.0
- 添加详细输出模式
- 支持自定义配置文件
- 改进的用户界面
