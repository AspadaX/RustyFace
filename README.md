# RustyFace
A command line app for downloading Huggingface repositories with Rust. 

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

# Why using this?
RustyFace does not require installing additional dependencies such as `git` or `git lfs` etc. It aims to be lightweight and portable. 
In addition to that, RustyFace is friendly to users who live in Mainland China, where HuggingFace accessibility is unstable, as this CLI app adopted a mirror that can be accessed globally.

The mirror site used in this project is `hf-mirror.com`

# How to Install and Use RustyFace
First, you need to have Rust installed. For those new to Rust, please refer to the [official installation guide](https://doc.rust-lang.org/cargo/getting-started/installation.html).

## Quickstart
You don't need to install Rust if you download the corresponding binaries to your platform from the Release section. That way, you can just type this command to download Huggingface repositories:
```
rustyface_windows_x86 --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4
```
- `rustyface_windows_x86` is the binary file name that you have downloaded from the Release section. 
- `--repository` is followed by the `repo_id` of the repository that you want to download from HuggingFace.
- `--tasks` is followed by the number of concurrent downloads. For example, 4 means downloading 4 files at once. It is recommended to use a lower number if your network conditions do not support higher concurrency.

## Install Rust
On Linux and macOS: 
```
curl https://sh.rustup.rs -sSf | sh
```
On Windows, you can download the installation executable via this link: https://win.rustup.rs/

## Install RustyFace
After done installing Rust, just type this to your terminal:
```
cargo install rustyface
```

## Use RustyFace to Download Repositories
Try RustyFace out with this simple command line:
```
rustyface --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4
```
- `--repository` is followed by the `repo_id` of the repository that you want to download from HuggingFace.
- `--tasks` is followed by the number of concurrent downloads. For example, 4 means downloading 4 files at once. It is recommended to use a lower number if your network conditions do not support higher concurrency.

# Feedback & Further Development
Any participation is appreciated! Feel free to submit an issue, discussion or pull request. You can find me on WeChat: `baoxinyu2007` or Discord: `https://discord.gg/UYfZeuPy`

# License
This project is licensed under the MIT License. See the LICENSE file for details.

## Packages Used
- [clap](https://crates.io/crates/clap) for command line argument parsing.
- [futures-util](https://crates.io/crates/futures-util) for asynchronous operations.
- [indicatif](https://crates.io/crates/indicatif) for progress bars.
- [log](https://crates.io/crates/log) for logging.
- [reqwest](https://crates.io/crates/reqwest) for HTTP requests.
- [sha2](https://crates.io/crates/sha2) for SHA-256 hashing.
- [tokio](https://crates.io/crates/tokio) for asynchronous runtime.
- [fern](https://crates.io/crates/fern) for logging configuration.
- [chrono](https://crates.io/crates/chrono) for date and time handling.
