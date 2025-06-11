# RustyFace
一个使用Rust开发的命令行工具，用于下载Huggingface仓库。

<p align="center">
  <img src="logo.jpg" alt="RustyFace Logo" width="200"/>
</p>

<p align="center">
  <a href="https://crates.io/crates/rustyface">
    <img src="https://img.shields.io/crates/v/rustyface.svg" alt="Crates.io">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
</p>

# 为什么使用RustyFace？
RustyFace不需要安装额外的依赖，如`git`或`git lfs`等。它旨在轻量化和便携化。
此外，RustyFace对中国大陆用户友好，因为在中国大陆访问HuggingFace可能不稳定，而此CLI应用程序采用了可全球访问的镜像站点。

本项目使用的镜像站点是`hf-mirror.com`

# 如何安装和使用RustyFace

## 快速安装（推荐）
安装RustyFace最简单的方法是使用我们的安装脚本，它会自动为您的平台下载最新的二进制文件：

### 一键安装
```bash
curl -sSL https://raw.githubusercontent.com/AspadaX/RustyFace/main/setup.sh | bash
```

或者手动下载并运行脚本：
```bash
wget https://raw.githubusercontent.com/AspadaX/RustyFace/main/setup.sh
chmod +x setup.sh
./setup.sh
```

### 管理脚本
安装后，您可以使用这些脚本来管理RustyFace：

**更新到最新版本：**
```bash
curl -sSL https://raw.githubusercontent.com/AspadaX/RustyFace/main/update.sh | bash
```

**卸载RustyFace：**
```bash
curl -sSL https://raw.githubusercontent.com/AspadaX/RustyFace/main/uninstall.sh | bash
```

## 其他安装方法

### 手动下载二进制文件
您可以从[Release部分](https://github.com/AspadaX/RustyFace/releases)下载对应平台的二进制文件。这样，您只需输入以下命令即可下载Huggingface仓库：
```
rustyface_windows_x86 --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4
```
- `rustyface_windows_x86`是您从Release部分下载的二进制文件名。
- `--repository`后跟您想从HuggingFace下载的仓库的`repo_id`。
- `--tasks`后跟并发下载数量。例如，4表示同时下载4个文件。如果您的网络条件不支持较高的并发性，建议使用较低的数值。

### 通过Cargo安装
如果您想从源代码构建，需要先安装Rust。对于Rust新手，请参考[官方安装指南](https://doc.rust-lang.org/cargo/getting-started/installation.html)。

#### 安装Rust
在Linux和macOS上：
```
curl https://sh.rustup.rs -sSf | sh
```
在Windows上，您可以通过此链接下载安装程序：https://win.rustup.rs/

#### 安装RustyFace
安装Rust后，只需在终端中输入：
```
cargo install rustyface
```

### 使用RustyFace下载仓库
尝试使用以下简单命令行：
```
rustyface --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4
```
- `--repository`后跟您想从HuggingFace下载的仓库的`repo_id`。
- `--tasks`后跟并发下载数量。例如，4表示同时下载4个文件。如果您的网络条件不支持较高的并发性，建议使用较低的数值。

# 反馈与进一步开发
非常感谢任何参与！欢迎提交问题、讨论或拉取请求。您可以在微信上找到我：`baoxinyu2007`或Discord：`https://discord.gg/UYfZeuPy`

# 许可证
本项目采用MIT许可证。详情请参阅LICENSE文件。

## 使用的包
- [clap](https://crates.io/crates/clap) 用于命令行参数解析。
- [futures-util](https://crates.io/crates/futures-util) 用于异步操作。
- [indicatif](https://crates.io/crates/indicatif) 用于进度条显示。
- [log](https://crates.io/crates/log) 用于日志记录。
- [reqwest](https://crates.io/crates/reqwest) 用于HTTP请求。
- [sha2](https://crates.io/crates/sha2) 用于SHA-256哈希运算。
- [tokio](https://crates.io/crates/tokio) 用于异步运行时。
- [fern](https://crates.io/crates/fern) 用于日志配置。
- [chrono](https://crates.io/crates/chrono) 用于日期和时间处理。