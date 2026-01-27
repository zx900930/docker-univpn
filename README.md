# Huawei UniVPN Client Docker Container with VNC/SOCKS/HTTP Proxy Access

[简体中文](README_zh.md)

[![Docker Hub](https://img.shields.io/docker/pulls/triatk/univpn.svg)](https://hub.docker.com/r/triatk/univpn) [![Docker Image Size](https://img.shields.io/docker/image-size/triatk/univpn/latest)](https://hub.docker.com/r/triatk/univpn)

This project provides a Docker container for the Huawei UniVPN GUI client (version **10781.18.1.0512**, released on May 12th, 2025), accessible via VNC or a web browser (noVNC). It also includes a SOCKS5 proxy (Dante) and an HTTP proxy (Tinyproxy) to route traffic from host applications through the container's VPN connection.

**New in this version:** The container includes an intelligent **Keep-Alive system** that can automatically restart the VPN client if the connection drops or the application crashes.

**Disclaimer:** This project is unofficial and not affiliated with or endorsed by Huawei. The Huawei UniVPN client software itself is proprietary to Huawei. While the client binary is included in this repository's `./bin` directory for build convenience, **you are responsible for complying with Huawei's terms of service and licensing agreements** regarding its use. This container is provided for technical convenience, isolation, and remote access purposes only. The maintainers of this repository do not grant you any license to use the Huawei software.

## Included Software Information (Version: 10781.18.1.0512)

| Field           | Value                                                               |
| :-------------- | :------------------------------------------------------------------ |
| Release         | **10781.18.1.0512**                                                 |
| Binary Location | Included in repository: `./bin/univpn-linux-64-10781.18.1.0512.zip` |
| Base OS         | Ubuntu 22.04 LTS                                                    |
| Access Method   | VNC (Port 5901), Web Browser via noVNC (Port 6901)                  |
| Proxy           | SOCKS5 (Dante) on Port 1080, HTTP (Tinyproxy) on Port 8888          |

## Key Features

- **Isolated GUI:** Run the Huawei UniVPN GUI client in a secure Docker container.
- **Remote Access:** Access via VNC clients or a web browser (noVNC).
- **Auto-Start & Keep-Alive:** The UniVPN client starts automatically. A keeper script monitors the process and can automatically restart it if it crashes or if the network connection is lost (Auto-Reconnect).
- **Proxies:**
  - **SOCKS5** (Port `1080`): Routes traffic through the VPN.
  - **HTTP** (Port `8888`): Chains to SOCKS5, allowing HTTP-based apps to use the VPN.
- **Configurable:** Managed via Docker Compose and `.env` files.
- **Privileges:** Includes `NET_ADMIN` and `TUN` device access required for VPNs.

## Prerequisites

- Docker installed on your host machine.
- Docker Compose installed (`docker-compose` or `docker compose`).
- The `tun` kernel module loaded on the host (`sudo modprobe tun`). Ensure `/dev/net/tun` exists.

## How to Use (Docker Compose Recommended)

1.  **Clone the Repository:**

    ```bash
    git clone https://github.com/zx900930/docker-univpn.git
    cd docker-univpn
    ```

2.  **Create `.env` File:**
    In the `docker-univpn` directory, create a file named `.env`. Copy the following content and adjust the values:

    ```dotenv
    # .env file

    # Security & Network
    VNC_PASSWORD=YourStrongVncPassword123
    SPOOF_MAC=00:1A:2B:3C:4D:5E

    # --- Auto Reconnect Settings ---
    # Set to 'true' to enable auto-restart when network connectivity is lost
    AUTO_RECONNECT=true

    # The IP address to ping to check connectivity (e.g. 8.8.8.8 or your VPN's internal gateway)
    RECONNECT_PING_TARGET=8.8.8.8

    # Time (in seconds) to wait for login before starting connectivity checks
    RECONNECT_GRACE_PERIOD=60
    ```

3.  **Start the Container:**

    ```bash
    docker-compose up -d
    ```

4.  **Connect to the GUI:**

    - **VNC Client:** Connect to `localhost:5901` (Password: `VNC_PASSWORD`).
    - **Web Browser:** Go to `http://localhost:6901/vnc.html` (Password: `VNC_PASSWORD`).

5.  **Use the Proxies:**
    - **SOCKS5:** `localhost:1080`
    - **HTTP:** `localhost:8888`

## CLI-Only Docker Image

This repository also provides a `Dockerfile.cli` for building a command-line interface (CLI) only version of the UniVPN client. This image is suitable for environments where GUI access is not needed, such as CI/CD pipelines, scripting, or headless servers.

**New Dockerfile:** `Dockerfile.cli`
**New Docker Image:** `triatk/univpn` (available on Docker Hub)

### Building the CLI Image

The existing CI workflow (`.github/workflows/docker-image.yml`) has been updated to automatically build and push the `triatk/univpn` image when changes are pushed to the `cli-only-image` branch.

To build it manually, you can use:

````bash
# Ensure you have the zip file in ./bin/
# Build the CLI image (replace 'latest' with a version tag if desired)
```bash
docker build -t triatk/univpn:latest-cli -f Dockerfile.cli .
````

### Using the CLI Image

The CLI image is designed for direct command execution. You would typically run commands like `vpn_client login`, `vpn_client connect`, etc., inside the container.

Example:

````bash
# To have your VPN credentials and profile configured, run
```bash
docker run --rm -it \
  -v ./univpn_config:/home/vpnuser/UniVPN \
  --name univpn \
  triatk/univpn:latest-cli \
  bash -c "/usr/local/UniVPN/serviceclient/UniVPNCS"
````

## Auto-Reconnect & Manual Restart

The container uses a wrapper script (`univpn-keeper.sh`) to manage the VPN application.

### Auto-Reconnect Logic

If `AUTO_RECONNECT=true` is set in your `.env` file:

1.  The VPN starts.
2.  The script waits for `RECONNECT_GRACE_PERIOD` seconds (giving you time to type your password/2FA).
3.  After the grace period, it pings `RECONNECT_PING_TARGET` every 10 seconds.
4.  If the ping fails (network timeout), the script **kills the VPN process**.
5.  The loop detects the process exit and **immediately restarts a fresh VPN instance**.

### Manual Restart

If the VPN freezes or you need to restart it manually without restarting the whole container:

- **From Host Terminal:**
  ```bash
  docker exec univpn-vnc reconnect
  ```
- **From Inside VNC:**
  Open the Fluxbox terminal (Right Click -> Applications -> Shells -> Bash) and type:
  ```bash
  reconnect
  ```

## Inside the Container

- The container runs a Fluxbox window manager.
- **UniVPN GUI** is launched by `/usr/local/bin/univpn-keeper.sh`.
- **Dante (SOCKS5)** and **Tinyproxy (HTTP)** run in the background via Supervisor.

## Configuration & Persistence

- **Environment Variables:** All settings are controlled via the `.env` file.
- **Persistence:** To save your VPN profiles and settings, uncomment the volume in `docker-compose.yml`:
  ```yaml
  volumes:
    - ./univpn_config:/home/vpnuser/UniVPN
  ```

## Troubleshooting

- **Looping Restarts:** If you see the VPN opening and closing repeatedly, check if `RECONNECT_PING_TARGET` is reachable. If the VPN blocks internet access but allows internal IPs, set the target to an internal server IP.
- **Not enough time to login:** Increase `RECONNECT_GRACE_PERIOD` in the `.env` file.
- **Container Crashing:** Check logs: `docker-compose logs univpn`.

## License

The Dockerfile and scripts in this repository are provided under the [MIT License](LICENSE). The Huawei software included in `./bin` is proprietary.

