# Huawei UniVPN Client Docker Container with VNC/SOCKS/HTTP Proxy Access

[简体中文](README_zh.md)

[![Docker Hub](https://img.shields.io/docker/pulls/triatk/univpn.svg)](https://hub.docker.com/r/triatk/univpn)
[![Docker Image Size](https://img.shields.io/docker/image-size/triatk/univpn/latest)](https://hub.docker.com/r/triatk/univpn)

This project provides a Docker container for the Huawei UniVPN GUI client (version **10781.18.1.0512**, released on May 12th, 2025), accessible via VNC or a web browser (noVNC). It also includes a SOCKS5 proxy (Dante) and an HTTP proxy (Tinyproxy) to route traffic from host applications through the container's VPN connection. The UniVPN application is configured to start automatically within the VNC session.

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

- Run the Huawei UniVPN GUI client in an isolated container.
- Access the GUI remotely via standard VNC clients or a web browser (noVNC).
- UniVPN client starts automatically within the VNC session (Fluxbox WM).
- Includes Chinese fonts for improved display compatibility.
- Provides a **SOCKS5 proxy** on port `1080` allowing host applications to use the container's VPN connection (respects container's routing table - split tunnel by default).
- Provides an **HTTP proxy** on port `8888` which chains to the SOCKS5 proxy, allowing host applications to use the container's VPN connection.
- Configured via Docker Compose for easy management.
- Supports setting a **custom MAC address** for the container.
- Includes necessary privileges (`NET_ADMIN`) and **TUN device access** (`/dev/net/tun`) required by many VPN clients.

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
    In the `docker-univpn` directory, create a file named `.env` to store your configuration secrets. Add the following lines, **replacing the example values** with your desired VNC password and the required MAC address:

    ```dotenv
    # .env file
    VNC_PASSWORD=YourStrongVncPassword123
    SPOOF_MAC=00:1A:2B:3C:4D:5E
    ```

    - `VNC_PASSWORD`: Password to access the VNC/noVNC session. **Choose a strong password.**
    - `SPOOF_MAC`: The specific MAC address required by your VPN server. Format: `XX:XX:XX:XX:XX:XX`.

3.  **Start the Container:**

    ```bash
    docker-compose up -d
    ```

    This will pull the image (if needed), create, and start the container in the background.

4.  **Connect to the GUI:** You have two options:

    - **Option A: VNC Client:**
      - Use a VNC viewer application (TigerVNC, RealVNC, Remmina, etc.).
      - Connect to: `localhost:5901` (or replace `localhost` with your Docker host's IP if connecting remotely).
      - Enter the `VNC_PASSWORD` you set in the `.env` file when prompted.
    - **Option B: Web Browser (noVNC):**
      - Open your web browser.
      - Navigate to: `http://localhost:6901/vnc.html` (or replace `localhost` with your Docker host's IP).
      - Click "Connect".
      - Enter the `VNC_PASSWORD` you set in the `.env` file when prompted.

5.  **Use the Proxies (Optional):**
    - Establish the VPN connection using the UniVPN client inside the VNC session first.
    - **SOCKS5 Proxy:**
      - Configure applications on your **host machine** (e.g., web browser, specific tools) to use a **SOCKS5 proxy**.
      - Proxy Host/IP: `localhost` (or `127.0.0.1`)
      - Proxy Port: `1080`
    - **HTTP Proxy:**
      - Configure applications on your **host machine** to use an **HTTP proxy**.
      - Proxy Host/IP: `localhost` (or `127.0.0.1`)
      - Proxy Port: `8888`
    - **Note:** Based on the default UniVPN routing table observed (split-tunnel), only traffic destined for the specific VPN networks configured by UniVPN will be routed through the tunnel via these proxies. General internet traffic will likely bypass the VPN.

## Inside the Container

- The container runs a lightweight Fluxbox window manager session.
- The **UniVPN GUI application (`/usr/local/UniVPN/UniVPN`) is launched automatically** when the VNC session starts.
- The standard Fluxbox right-click menu may not function reliably in this setup; interaction should primarily be through the auto-launched UniVPN application.
- The Dante SOCKS5 proxy waits for the `cnem_vnic` interface (created by UniVPN) before starting its service.
- The Tinyproxy HTTP proxy starts after Dante and forwards requests to it.

## Configuration

- **VNC Password & MAC Address:** Configure via the `.env` file (see Step 2 above).
- **Ports, Resources, Capabilities:** Modify the `docker-compose.yml` file if needed.
- **UniVPN Client Settings:** Configure the UniVPN client itself _inside_ the VNC session as you normally would. For persistence of these settings across container restarts, consider adding a volume mount in `docker-compose.yml` to map a host directory to the client's configuration directory within the container (location depends on the client).
  ```yaml
  # Example volume mount in docker-compose.yml:
  # volumes:
  #   - ./univpn_client_config:/home/vpnuser/UniVPN
  ```

## Troubleshooting

- **Container Crashing:** Check logs immediately: `docker-compose logs univpn`
- **Cannot Connect to VNC/noVNC:** Ensure the container is running (`docker ps`), check port mappings in `docker-compose.yml`, verify firewall rules on the host.
- **VPN Connection Fails:**
  - Check UniVPN client logs inside the VNC session.
  - Verify `NET_ADMIN` and `/dev/net/tun` access are correctly configured in `docker-compose.yml`.
  - Ensure the `SPOOF_MAC` in `.env` is correct.
  - As a last resort, if specific device access or capabilities are missing, you _might_ need `privileged: true` in `docker-compose.yml`, but understand the security implications.
- **SOCKS/HTTP Proxy Not Working:**
  - Ensure the VPN is connected inside the container _before_ trying to use the proxy.
  - Check Dante logs: `docker exec -it <container_name> cat /var/log/sockd.log` or supervisor logs `/var/log/supervisor/danted_*.log`.
  - Check Tinyproxy logs: `docker exec -it <container_name> cat /var/log/tinyproxy.log` or supervisor logs `/var/log/supervisor/tinyproxy_*.log`.
  - Verify host application proxy settings (e.g., SOCKS5 for port 1080, HTTP for port 8888, localhost).

## Building Locally (Alternative)

While using Docker Compose is recommended, you can build the image manually:

```bash
# Make sure you have the correct VNC password for the build arg
docker build --build-arg VNC_PASSWORD=YourSecurePassword123 . -t my-univpn-vnc:latest
```

You would then need a complex `docker run` command equivalent to the `docker-compose.yml` settings.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

The Dockerfile and scripts in this repository are provided under the [MIT License](LICENSE) .

**Important:** This license applies _only_ to the files created for this project (Dockerfile, scripts, documentation). It **does not** apply to the Huawei UniVPN client software located in the `./bin` directory, which is governed by its own license agreement provided by Huawei. Your use of the included Huawei software is subject to your acceptance of Huawei's terms.
