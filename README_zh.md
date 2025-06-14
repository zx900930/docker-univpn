# 华为 UniVPN 客户端 Docker 容器 (带 VNC/SOCKS/HTTP 代理访问)

[English Version](README.md)

[![Docker Hub](https://img.shields.io/docker/pulls/triatk/univpn.svg)](https://hub.docker.com/r/triatk/univpn)
[![Docker Image Size](https://img.shields.io/docker/image-size/triatk/univpn/latest)](https://hub.docker.com/r/triatk/univpn)

本项目提供了一个用于华为 UniVPN 图形界面客户端 (版本 10781.18.0.0116) 的 Docker 容器，可通过 VNC 或 Web 浏览器 (noVNC) 访问。它还包含一个 SOCKS5 代理 (Dante) 和一个 **HTTP 代理 (Tinyproxy)**，允许宿主机应用程序通过容器的 VPN 连接路由流量。UniVPN 应用程序配置为在 VNC 会话中自动启动。

**免责声明：** 本项目为非官方项目，与华为公司无任何关联，也未获得华为公司的认可。华为 UniVPN 客户端软件本身为华为公司的专有财产。尽管为了方便构建，客户端二进制文件已包含在本仓库的 `./bin` 目录中，但**您有责任在使用时遵守华为的服务条款和许可协议**。此容器仅为技术便利、环境隔离和远程访问目的而提供。本仓库的维护者不授予您任何使用华为软件的许可。

## 内含软件信息 (版本: 10781.18.0.0116)

| 字段           | 值                                                           |
| :------------- | :----------------------------------------------------------- |
| Release 版本   | **10781.18.0.0116**                                          |
| 二进制文件位置 | 包含在仓库中: `./bin/univpn-linux-64-10781.18.0.0116.zip`    |
| 基础操作系统   | Ubuntu 22.04 LTS                                             |
| 访问方式       | VNC (端口 5901), Web 浏览器通过 noVNC (端口 6901)            |
| 代理           | SOCKS5 (Dante) 在端口 1080, **HTTP (Tinyproxy) 在端口 8888** |

## 主要特性

- 在隔离的容器中运行华为 UniVPN 图形界面客户端。
- 通过标准 VNC 客户端或 Web 浏览器 (noVNC) 远程访问 GUI。
- UniVPN 客户端在 VNC 会话中自动启动 (Fluxbox 窗口管理器)。
- 包含中文字体以改善显示兼容性。
- 提供一个位于端口 `1080` 的 **SOCKS5 代理**，允许宿主机应用程序使用容器的 VPN 连接（遵循容器的路由表 - 默认为分割隧道）。
- **提供一个位于端口 `8888` 的 HTTP 代理，它会链式转发到 SOCKS5 代理，从而允许宿主机应用程序使用容器的 VPN 连接。**
- 通过 Docker Compose 配置，方便管理。
- 支持为容器设置**自定义 MAC 地址**。
- 包含许多 VPN 客户端所需的必要权限 (`NET_ADMIN`) 和 **TUN 设备访问** (`/dev/net/tun`)。

## 先决条件

- 您的宿主机上已安装 Docker。
- 您的宿主机上已安装 Docker Compose (`docker-compose` 或 `docker compose`)。
- 宿主机已加载 `tun` 内核模块 (`sudo modprobe tun`)。确保 `/dev/net/tun` 设备存在。

## 如何使用 (推荐 Docker Compose)

1.  **克隆仓库:**

    ```bash
    git clone https://github.com/zx900930/docker-univpn.git
    cd docker-univpn
    ```

2.  **创建 `.env` 文件:**
    在 `docker-univpn` 目录下，创建一个名为 `.env` 的文件来存储您的配置秘密信息。添加以下行，并将**示例值替换**为您想要的 VNC 密码和所需的 MAC 地址：

    ```dotenv
    # .env 文件
    VNC_PASSWORD=YourStrongVncPassword123
    SPOOF_MAC=00:1A:2B:3C:4D:5E
    ```

    - `VNC_PASSWORD`: 用于访问 VNC/noVNC 会话的密码。**请选择一个强密码。**
    - `SPOOF_MAC`: 您的 VPN 服务器要求的特定 MAC 地址。格式：`XX:XX:XX:XX:XX:XX`。

3.  **启动容器:**

    ```bash
    docker-compose up -d
    ```

    这将拉取镜像（如果需要）、创建并在后台启动容器。

4.  **连接到 GUI:** 您有两种选择：

    - **选项 A: VNC 客户端:**
      - 使用 VNC 查看器应用程序 (如 TigerVNC, RealVNC, Remmina 等)。
      - 连接到: `localhost:5901` (如果远程连接，请将 `localhost` 替换为 Docker 主机的 IP)。
      - 在提示时输入您在 `.env` 文件中设置的 `VNC_PASSWORD`。
    - **选项 B: Web 浏览器 (noVNC):**
      - 打开您的网页浏览器。
      - 访问: `http://localhost:6901/vnc.html` (如果远程连接，请将 `localhost` 替换为 Docker 主机的 IP)。
      - 点击 "Connect"。
      - 在提示时输入您在 `.env` 文件中设置的 `VNC_PASSWORD`。

5.  **使用代理 (可选):**
    - 首先在 VNC 会话中使用 UniVPN 客户端建立 VPN 连接。
    - **SOCKS5 代理:**
      - 在您的**宿主机**上配置应用程序（例如，Web 浏览器、特定工具）以使用 **SOCKS5 代理**。
      - 代理主机/IP: `localhost` (或 `127.0.0.1`)
      - 代理端口: `1080`
    - **HTTP 代理:**
      - 在您的**宿主机**上配置应用程序以使用 **HTTP 代理**。
      - 代理主机/IP: `localhost` (或 `127.0.0.1`)
      - 代理端口: `8888`
    - **注意:** 基于观察到的默认 UniVPN 路由表（分割隧道），只有目标地址是 UniVPN 配置的特定 VPN 网络流量才会通过这些代理经过隧道。常规的互联网流量很可能会绕过 VPN。

## 容器内部

- 容器运行一个轻量级的 Fluxbox 窗口管理器会话。
- **UniVPN GUI 应用程序 (`/usr/local/UniVPN/UniVPN`)** 在 VNC 会话启动时**自动运行**。
- 在此设置中，标准的 Fluxbox 右键菜单可能无法可靠工作；交互应主要通过自动启动的 UniVPN 应用程序进行。
- Dante SOCKS5 代理会等待 UniVPN 创建 `cnem_vnic` 接口后才启动其服务。
- **Tinyproxy HTTP 代理在 Dante 启动后开始运行，并将请求转发给 Dante。**

## 配置

- **VNC 密码 & MAC 地址:** 通过 `.env` 文件配置（见上方第 2 步）。
- **端口、资源、权限:** 如果需要，修改 `docker-compose.yml` 文件。
- **UniVPN 客户端设置:** 像平常一样，在 VNC 会话*内部*配置 UniVPN 客户端本身。为了在容器重启后保持这些设置，可以考虑在 `docker-compose.yml` 中添加卷挂载，将宿主机目录映射到容器内客户端的配置目录（具体位置取决于客户端）。
  ```yaml
  # docker-compose.yml 中的卷挂载示例:
  # volumes:
  #   - ./univpn_client_config:/home/vpnuser/UniVPN # 根据需要调整路径
  ```

## 问题排查

- **容器崩溃:** 立即检查日志: `docker-compose logs univpn`
- **无法连接 VNC/noVNC:** 确保容器正在运行 (`docker ps`)，检查 `docker-compose.yml` 中的端口映射，检查宿主机的防火墙规则。
- **VPN 连接失败:**
  - 在 VNC 会话内检查 UniVPN 客户端日志。
  - 确认 `NET_ADMIN` 和 `/dev/net/tun` 访问权限在 `docker-compose.yml` 中已正确配置。
  - 确保 `.env` 文件中的 `SPOOF_MAC` 正确。
  - 作为最后手段，如果缺少特定的设备访问或权限，您*可能*需要在 `docker-compose.yml` 中设置 `privileged: true`，但请理解其安全风险。
- **SOCKS/HTTP 代理不工作:**
  - 确保在尝试使用代理之前，容器内的 VPN 已连接。
  - 检查 Dante 日志: `docker exec -it <container_name> cat /var/log/sockd.log` 或 supervisor 日志 `/var/log/supervisor/danted_*.log`。
  - **检查 Tinyproxy 日志: `docker exec -it <container_name> cat /var/log/tinyproxy.log` 或 supervisor 日志 `/var/log/supervisor/tinyproxy_*.log`。**
  - 验证宿主机应用程序的代理设置 (例如，SOCKS5 对应端口 1080，HTTP 对应端口 8888，主机为 localhost)。

## 本地构建 (替代方案)

虽然推荐使用 Docker Compose，但您也可以手动构建镜像：

```bash
# 确保为构建参数提供正确的 VNC 密码
docker build --build-arg VNC_PASSWORD=YourSecurePassword123 . -t my-univpn-vnc:latest
```

然后，您将需要一个复杂的 `docker run` 命令，等同于 `docker-compose.yml` 中的设置。

## 贡献

欢迎贡献！请随时提交 Issues 和 Pull Requests。

## 许可证

本仓库中的 Dockerfile 和脚本根据 [MIT 许可证](LICENSE) 提供。

**重要提示：** 此许可证 _仅适用于_ 为本项目创建的文件（Dockerfile、脚本、文档）。它 **不适用于** 位于 `./bin` 目录中的华为 UniVPN 客户端软件，该软件受华为提供的其自身的许可协议约束。您对所包含的华为软件的使用取决于您接受华为的条款。
