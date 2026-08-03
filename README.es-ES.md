# Contenedor Docker del cliente UniVPN de Huawei con acceso a VNC/Proxy SOCKS/Proxy HTTP

[简体中文](README_zh.md)

[![Docker Hub](https://img.shields.io/docker/pulls/triatk/univpn.svg)](https://hub.docker.com/r/triatk/univpn) [![Tamaño de la imagen Docker](https://img.shields.io/docker/image-size/triatk/univpn/latest)](https://hub.docker.com/r/triatk/univpn)

Este proyecto ofrece un contenedor Docker para el cliente gráfico Huawei UniVPN (versión **10781.19.0.1214**, lanzada el 12 de mayo de 2025), accesible a través de VNC o de un navegador web (noVNC). También incluye un proxy SOCKS5 (Dante) y un proxy HTTP (Tinyproxy) para redirigir el tráfico de las aplicaciones del host a través de la conexión VPN del contenedor.

**Novedad en esta versión:** El contenedor incluye un sistema inteligente de **mantenimiento de la conexión** que puede reiniciar automáticamente el cliente VPN si la conexión se interrumpe o si la aplicación se cierra inesperadamente.

**Aviso legal:** Este proyecto no es oficial y no está afiliado ni respaldado por Huawei. El software del cliente Huawei UniVPN es propiedad exclusiva de Huawei. Aunque el archivo binario del cliente está incluido en el directorio `./bin` de este repositorio para facilitar la compilación, **usted es responsable de cumplir con los términos de servicio y los acuerdos de licencia de Huawei** en relación con su uso. Este contenedor se proporciona únicamente con fines de conveniencia técnica, aislamiento y acceso remoto. Los mantenedores de este repositorio no le otorgan ninguna licencia para utilizar el software de Huawei.

## Información sobre el software incluido (Versión: 10781.19.0.1214)

| Campo            | Valor                                                               |
| :--------------- | :------------------------------------------------------------------ |
| Versión          | **10781.19.0.1214**                                                 |
| Ubicación del binario | Incluido en el repositorio: `./bin/univpn-linux-64-10781.19.0.1214.zip` |
| Sistema operativo base | Ubuntu 22.04 LTS                                                    |
| Método de acceso  | VNC (Puerto 5901), Navegador web mediante noVNC (Puerto 6901)        |
| Proxy            | SOCKS5 (Dante) en el Puerto 1080, HTTP (Tinyproxy) en el Puerto 8888 |

## Características principales

- **Interfaz gráfica aislada:** Ejecute el cliente gráfico Huawei UniVPN en un contenedor Docker seguro.
- **Acceso remoto:** Conéctese a través de clientes VNC o de un navegador web (noVNC).
- **Inicio automático y mantenimiento de la conexión:** El cliente UniVPN se inicia automáticamente. Un script de supervisión controla el proceso y puede reiniciarlo automáticamente si se bloquea o si se pierde la conexión de red (Auto-Reconexión).
- **Proxies:**
  - **SOCKS5** (Puerto `1080`): Redirige el tráfico a través de la VPN.
  - **HTTP** (Puerto `8888`): Se conecta al SOCKS5, permitiendo que las aplicaciones basadas en HTTP utilicen la VPN.
- **Configurable:** Gestionado mediante Docker Compose y archivos `.env`.
- **Privilegios:** Incluye acceso a los dispositivos `NET_ADMIN` y `TUN` necesarios para las VPN.

## Requisitos previos

- Docker instalado en su máquina host.
- Docker Compose instalado (`docker-compose` o `docker compose`).
- El módulo kernel `tun` cargado en el host (`sudo modprobe tun`). Asegúrese de que `/dev/net/tun` exista.

## Cómo utilizarlo (recomendado: Docker Compose)

1. **Clonar el repositorio:**

    ```bash
    git clone https://github.com/zx900930/docker-univpn.git
    cd docker-univpn
    ```

2. **Crear el archivo `.env`:**
    En el directorio `docker-univpn`, cree un archivo llamado `.env`. Copie el siguiente contenido y ajuste los valores:

    ```dotenv
    # archivo .env

    # Credenciales de VPN (REQUERIDAS SI SE UTILIZA LA IMAGEN CLI)
    VPN_USERNAME=su_usuario_aqui
    VPN_PASSWORD=su_contraseña_aqui

    # Seguridad y red
    VNC_PASSWORD=SuContrasenaVncFuerte123
    SPOOF_MAC=00:1A:2B:3C:4D:5E

    # --- Configuración de Auto Reconnect --- 
    # Establezca en 'true' para habilitar el reinicio automático cuando se pierda la conectividad de red
    AUTO_RECONNECT=true

    # La dirección IP a la que hacer ping para verificar la conectividad (por ejemplo, 8.8.8.8 o la puerta de enlace interna de su VPN)
    RECONNECT_PING_TARGET=8.8.8.8

    # Tiempo (en segundos) para esperar el inicio de sesión antes de comenzar las comprobaciones de conectividad
    RECONNECT_GRACE_PERIOD=60
    ```

3. **Iniciar el contenedor:**

    ```bash
    docker-compose up -d
    ```

4. **Conectar a la interfaz gráfica:**

    - **Cliente VNC:** Conéctese a `localhost:5901` (Contraseña: `VNC_PASSWORD`).
    - **Navegador web:** Vaya a `http://localhost:6901/vnc.html` (Contraseña: `VNC_PASSWORD`).

5. **Utilizar los proxies:**
    - **SOCKS5:** `localhost:1080`
    - **HTTP:** `localhost:8888`

## Imagen Docker solo para CLI

Este repositorio también proporciona un `Dockerfile.cli` para construir una versión solo de línea de comandos (CLI) del cliente UniVPN de Huawei. Esta imagen es adecuada para entornos en los que no se necesita acceso gráfico, como pipelines de CI/CD, scripting o servidores sin interfaz.

**Nuevo Dockerfile:** `Dockerfile.cli`
**Nueva imagen Docker:** `triatk/univpn` (disponible en Docker Hub)

### Construir la imagen CLI

El flujo de trabajo de CI existente (`.github/workflows/docker-image.yml`) ha sido actualizado para construir y publicar automáticamente la imagen `triatk/univpn` cuando se realizan cambios en la rama `cli-only-image`.

Para construirla manualmente, puede utilizar:

```bash
# Asegúrate de que el archivo zip esté en ./bin/
# Construir la imagen CLI (reemplace 'latest' con una etiqueta de versión si lo desea)
docker build -t triatk/univpn:latest-cli -f Dockerfile.cli .
```

### Usar la imagen CLI

La imagen CLI está diseñada para la ejecución directa de comandos. Por lo general, se ejecutarían comandos como `vpn_client login`, `vpn_client connect`, etc., dentro del contenedor.

Ejemplo:

```bash
# Para tener sus credenciales de VPN y perfil configurados, ejecute
docker run --rm -it \
  -v ./univpn_config:/home/vpnuser/UniVPN \
  --name univpn \
  triatk/univpn:latest-cli \
  bash -c "/usr/local/UniVPN/serviceclient/UniVPNCS"
```

## Auto-Reconexión y reinicio manual

El contenedor utiliza un script envolvente (`univpn-keeper.sh`) para gestionar la aplicación VPN.

### Lógica de Auto-Reconexión

Si `AUTO_RECONNECT=true` está configurado en su archivo `.env`:

1. La VPN se inicia.
2. El script espera durante `RECONNECT_GRACE_PERIOD` segundos (dándole tiempo para ingresar su contraseña/2FA).
3. Después del período de gracia, hace ping a `RECONNECT_PING_TARGET` cada 10 segundos.
4. Si el ping falla (tiempo de espera de la red), el script **mata el proceso VPN**.
5. El bucle detecta la salida del proceso y **reinicia inmediatamente una nueva instancia de VPN**.

### Reinicio manual

Si la VPN se bloquea o necesita reiniciarla manualmente sin reiniciar todo el contenedor:

- **Desde el terminal del host:**
  ```bash
  docker exec univpn-vnc reconnect
  ```
- **Desde dentro de VNC:**
  Abra el terminal Fluxbox (Clic derecho -> Aplicaciones -> Shells -> Bash) y escriba:
  ```bash
  reconnect
  ```

## Dentro del contenedor

- El contenedor ejecuta un gestor de ventanas Fluxbox.
- **UniVPN GUI** es lanzado por `/usr/local/bin/univpn-keeper.sh`.
- **Dante (SOCKS5)** y **Tinyproxy (HTTP)** se ejecutan en segundo plano a través de Supervisor.

## Configuración y persistencia

- **Variables de entorno:** Todas las configuraciones se controlan a través del archivo `.env`.
- **Persistencia:** Para guardar sus perfiles y configuraciones de VPN, descomente el volumen en `docker-compose.yml`:
    ```yaml
    volumes:
      - ./univpn_config:/home/vpnuser/UniVPN
    ```

## Solución de problemas

- **Reinicios continuos:** Si ve que la VPN se abre y se cierra repetidamente, compruebe si `RECONNECT_PING_TARGET` es alcanzable. Si la VPN bloquea el acceso a internet pero permite las IPs internas, establezca el objetivo a la IP de un servidor interno.
- **No hay tiempo suficiente para iniciar sesión:** Aumente `RECONNECT_GRACE_PERIOD` en el archivo `.env`.
- **El contenedor se bloquea:** Compruebe los registros: `docker-compose logs univpn`.

## Licencia

El Dockerfile y los scripts de este repositorio se proporcionan bajo la [Licencia MIT](LICENSE). El software de Huawei incluido en `./bin` es de propiedad exclusiva de Huawei.
