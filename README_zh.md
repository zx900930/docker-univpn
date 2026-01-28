# 华为 UniVPN 客户端 Docker 容器 (带 VNC/SOCKS/HTTP 代理访问)

[English Version](README.md)

[![Docker Hub](https://img.shields.io/docker/pulls/triatk/univpn.svg)](https://hub.docker.com/r/triatk/univpn)
[![Docker Image Size](https://img.shields.io/docker/image-size/triatk/univpn/latest)](https://hub.docker.com/r/triatk/univpn)

本项目提供了一个用于华为 UniVPN 图形界面客户端 (版本 **10781.18.1.0512**，发布于 2025 年 5 月 12 日) 的 Docker 容器，可通过 VNC 或 Web 浏览器 (noVNC) 访问。它还包含 SOCKS5 和 HTTP 代理，允许宿主机应用程序通过容器的 VPN 连接路由流量。

**本版本新增功能：** 容器包含智能**保活系统 (Keep-Alive)**，如果连接断开或应用程序崩溃，它可以自动重启 VPN 客户端。

**免责声明：** 本项目为非官方项目，与华为公司无任何关联。华为 UniVPN 客户端软件本身为华为公司的专有财产。尽管为了方便构建，二进制文件已包含在 `./bin` 目录中，但**您有责任在使用时遵守华为的服务条款和许可协议**。

## 内含软件信息 (版本: 10781.18.1.0512)

| 字段           | 值                                                           |
| :------------- | :----------------------------------------------------------- |
| Release 版本   | **10781.18.1.0512**                                          |
| 二进制文件位置 | 包含在仓库中: `./bin/univpn-linux-64-10781.18.1.0512.zip`    |
| 基础操作系统   | Ubuntu 22.04 LTS                                             |
| 访问方式       | VNC (端口 5901), Web 浏览器通过 noVNC (端口 6901)            |
| 代理           | SOCKS5 (Dante) 在端口 1080, **HTTP (Tinyproxy) 在端口 8888** |

## 主要特性

- **隔离的 GUI:** 在安全的 Docker 容器中运行华为 UniVPN。
- **远程访问:** 支持 VNC 客户端或 Web 浏览器 (noVNC)。
- **自动启动与保活 (Keep-Alive):** UniVPN 客户端自动启动。内置守护脚本会监控进程，若进程崩溃或网络连接丢失（自动重连），脚本会自动重启 VPN。
- **双重代理:**
  - **SOCKS5** (端口 `1080`): 通过 VPN 路由流量。
  - **HTTP** (端口 `8888`): 链式转发到 SOCKS5，允许 HTTP 应用使用 VPN。
- **易于配置:** 通过 Docker Compose 和 `.env` 文件管理。
- **必要权限:** 包含 `NET_ADMIN` 和 `TUN` 设备访问权限。

## 先决条件

- 宿主机已安装 Docker 和 Docker Compose。
- 宿主机已加载 `tun` 内核模块 (`sudo modprobe tun`)。

## 如何使用 (推荐 Docker Compose)

1.  **克隆仓库:**

    ```bash
    git clone https://github.com/zx900930/docker-univpn.git
    cd docker-univpn
    ```

2.  **创建 `.env` 文件:**
    在 `docker-univpn` 目录下创建一个名为 `.env` 的文件。复制以下内容并根据需要修改：

    ```dotenv
    # .env 文件

    # VPN账号设置 (只有使用CLI镜像时需要)
    VPN_USERNAME=your_username_here
    VPN_PASSWORD=your_password_here

    # 安全与网络设置
    VNC_PASSWORD=YourStrongVncPassword123
    SPOOF_MAC=00:1A:2B:3C:4D:5E

    # --- 自动重连 (Auto Reconnect) 设置 ---
    # 设置为 'true' 以启用网络断开时的自动重启
    AUTO_RECONNECT=true

    # 用于检测连接状态的目标 IP (例如 8.8.8.8 或公司内网网关)
    RECONNECT_PING_TARGET=8.8.8.8

    # 启动后等待登录的宽限期 (秒)，在此期间不进行 Ping 检测
    RECONNECT_GRACE_PERIOD=60
    ```

3.  **启动容器:**

    ```bash
    docker-compose up -d
    ```

4.  **连接到 GUI:**

    - **VNC 客户端:** 连接到 `localhost:5901` (密码: `VNC_PASSWORD`)。
    - **Web 浏览器:** 访问 `http://localhost:6901/vnc.html` (密码: `VNC_PASSWORD`)。

5.  **使用代理:**
    - **SOCKS5:** `localhost:1080`
    - **HTTP:** `localhost:8888`

## 纯命令行 (CLI) Docker 镜像

本仓库还提供了一个 `Dockerfile.cli` 文件，用于构建 UniVPN 客户端的纯命令行 (CLI) 版本。此镜像适用于不需要图形界面的环境，例如 CI/CD 流水线、脚本编写或无头服务器。

**新的 Dockerfile:** `Dockerfile.cli`
**新的 Docker 镜像:** `triatk/univpn-cli` (可在 Docker Hub 上找到)

### 构建 CLI 镜像

已更新 CI 工作流程 (`.github/workflows/docker-image.yml`)，当推送到 `cli-only-image` 分支时，会自动构建并推送 `triatk/univpn-cli` 镜像。

您也可以手动构建：

```bash
# 确保您的 bin/ 目录下有 zip 文件
# 构建 CLI 镜像 (可选：将 'latest' 替换为版本标签)
docker build -t triatk/univpn-cli:latest -f Dockerfile.cli .

# 推送到 Docker Hub (需要登录)
# docker login
# docker push triatk/univpn-cli:latest
```

### 使用 CLI 镜像

CLI 镜像设计用于纯命令行运行UniVPN。

首次使用 (需要输入以下命令手动配置好 VPN 凭据和配置文件):

```bash
# 假设您已配置好 VPN 凭据和配置文件
# 并且 Dockerfile.cli 使用 CMD 启动 bash
docker run --rm -it \
  -v ./univpn_config:/home/vpnuser/UniVPN \
  --name univpn-cli \
  triatk/univpn-cli:latest \
  bash -c "/usr/local/UniVPN/UniVPN"
```

_注意：实际使用时，您可能需要调整 `Dockerfile.cli` 中的 `CMD` 命令，或在 `docker run` 命令中指定具体要执行的命令。当前 `Dockerfile.cli` 的 `CMD` 是 `["/bin/bash"]`，允许交互式 shell 访问。_

## 自动重连与手动重启

容器使用包装脚本 (`univpn-keeper.sh`) 来管理 VPN 应用程序。

### 自动重连逻辑

如果在 `.env` 文件中设置了 `AUTO_RECONNECT=true`:

1.  VPN 启动。
2.  脚本等待 `RECONNECT_GRACE_PERIOD` 秒（给您时间输入密码/2FA）。
3.  宽限期过后，脚本每 10 秒 Ping 一次 `RECONNECT_PING_TARGET`。
4.  如果 Ping 失败（网络超时），脚本会**强制结束 VPN 进程**。
5.  循环逻辑检测到进程退出，随即**自动启动一个新的 VPN 实例**。

### 手动重启

如果 VPN 卡死，或者您需要手动重启它而不想重启整个容器：

- **从宿主机终端:**
  ```bash
  docker exec univpn-vnc reconnect
  ```
- **从 VNC 内部:**
  打开 Fluxbox 终端 (右键 -> Applications -> Shells -> Bash) 并输入:
  ```bash
  reconnect
  ```

## 容器内部

- 容器运行 Fluxbox 窗口管理器。
- **UniVPN GUI** 由 `/usr/local/bin/univpn-keeper.sh` 脚本启动。
- **Dante (SOCKS5)** 和 **Tinyproxy (HTTP)** 通过 Supervisor 在后台运行。

## 配置与持久化

- **环境变量:** 所有设置均通过 `.env` 文件控制。
- **持久化:** 要保存您的 VPN 配置文件和设置，请取消注释 `docker-compose.yml` 中的 volume 配置:
  ```yaml
  volumes:
    - ./univpn_config:/home/vpnuser/UniVPN
  ```

## 故障排除

- **无限重启循环:** 如果看到 VPN 反复打开和关闭，请检查 `RECONNECT_PING_TARGET` 是否可达。如果 VPN 禁止访问外网但允许访问内网，请将目标 IP 设置为内网服务器 IP。
- **登录时间不足:** 在 `.env` 文件中增加 `RECONNECT_GRACE_PERIOD` 的值。
- **容器崩溃:** 查看日志: `docker-compose logs univpn`。

## 许可证

本仓库中的 Dockerfile 和脚本根据 [MIT 许可证](LICENSE) 提供。`./bin` 目录中的华为软件受其专有协议约束。
