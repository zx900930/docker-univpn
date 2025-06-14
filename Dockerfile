# Use Ubuntu 22.04 LTS as the base image
FROM ubuntu:22.04

# Set Arguments
ARG CLIENT_VERSION=10781.18.0.0116
ARG ZIP_FILE_REL_PATH=bin/univpn-linux-64-${CLIENT_VERSION}.zip
ARG INSTALLER_SOURCE_DIR=/home/UniVPN
ARG INSTALLER_RUN_FILE=univpn-linux-64-${CLIENT_VERSION}.run
ARG ACTUAL_INSTALL_DIR=/usr/local/UniVPN
ARG GUI_APP_PATH=${ACTUAL_INSTALL_DIR}
ARG GUI_APP_EXEC=UniVPN
ARG INSTALL_LOG_DIR=${ACTUAL_INSTALL_DIR}/log
ARG INSTALL_LOG_FILE=${INSTALL_LOG_DIR}/install.log
ARG FONTS_DIR=/usr/share/fonts
ARG USERNAME=vpnuser
ARG USER_UID=1000
ARG USER_GID=1000
ARG VNC_PASSWORD=univpn
ARG VNC_RESOLUTION=1280x800
ARG VNC_DEPTH=24

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV DISPLAY=:1
ENV VNC_RESOLUTION=${VNC_RESOLUTION}
ENV VNC_PW=${VNC_PASSWORD}
ENV VNC_DEPTH=${VNC_DEPTH}
ENV TZ=Asia/Shanghai

# --- Pre-configure debconf for keyboard-configuration ---
RUN echo "keyboard-configuration keyboard-configuration/layoutcode string us" | debconf-set-selections && \
    echo "keyboard-configuration keyboard-configuration/modelcode string pc105" | debconf-set-selections && \
    echo "keyboard-configuration keyboard-configuration/variantcode string ''" | debconf-set-selections && \
    echo "keyboard-configuration keyboard-configuration/xkb-keymap select us" | debconf-set-selections

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unzip \
    locales \
    ca-certificates \
    sudo \
    net-tools \
    iproute2 \
    dante-server \   
    tinyproxy \   
    dbus \
    tzdata \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libqt5widgets5 \
    libqt5gui5 \
    libqt5core5a \
    libqt5dbus5 \
    fonts-liberation \
    fonts-noto-core \
    fonts-wqy-zenhei \
    tigervnc-standalone-server \
    tigervnc-tools \
    fluxbox \
    supervisor \
    novnc \
    websockify \
    && \
    locale-gen C.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure timezone and fix dbus directory permissions
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    mkdir -p /var/run/dbus && \
    chown messagebus:messagebus /var/run/dbus

# --- Add Font Cache Update Step ---
RUN echo "Updating font cache..." && \
    fc-cache -fv && \
    echo "Font cache updated."

# Prevent system to start a WM before fluxbox
RUN echo "Replacing /etc/X11/Xtigervnc-session..." && \
    # Create a simplified session script
    echo '#!/bin/sh' > /etc/X11/Xtigervnc-session && \
    echo '' >> /etc/X11/Xtigervnc-session && \
    # Optional: Set keyboard layout if needed
    echo 'if test -r /etc/default/keyboard && test -x /usr/bin/setxkbmap; then' >> /etc/X11/Xtigervnc-session && \
    echo '  . /etc/default/keyboard' >> /etc/X11/Xtigervnc-session && \
    echo '  /usr/bin/setxkbmap \' >> /etc/X11/Xtigervnc-session && \
    echo '    -model   "${XKBMODEL}" \' >> /etc/X11/Xtigervnc-session && \
    echo '    -layout  "${XKBLAYOUT}" \' >> /etc/X11/Xtigervnc-session && \
    echo '    -variant "${XKBVARIANT}" \' >> /etc/X11/Xtigervnc-session && \
    echo '    "${XKBOPTIONS}"' >> /etc/X11/Xtigervnc-session && \
    echo 'fi' >> /etc/X11/Xtigervnc-session && \
    echo '' >> /etc/X11/Xtigervnc-session && \
    # Optional: Start vncconfig if you want it
    echo 'tigervncconfig -iconic &' >> /etc/X11/Xtigervnc-session && \
    echo '' >> /etc/X11/Xtigervnc-session && \
    # --- Add UniVPN launch ---
    echo '# Launch UniVPN in the background' >> /etc/X11/Xtigervnc-session && \
    echo '/usr/local/UniVPN/UniVPN &' >> /etc/X11/Xtigervnc-session && \
    # --- End UniVPN launch ---
    echo '' >> /etc/X11/Xtigervnc-session && \
    # --- Add a wait loop to keep the session alive ---
    echo '# Keep session running until explicitly killed' >> /etc/X11/Xtigervnc-session && \
    echo 'while true; do' >> /etc/X11/Xtigervnc-session && \
    echo '  sleep 3600' >> /etc/X11/Xtigervnc-session && \
    echo 'done' >> /etc/X11/Xtigervnc-session && \
    # --- End wait loop ---
    echo '' >> /etc/X11/Xtigervnc-session && \
    chmod +x /etc/X11/Xtigervnc-session && \
    echo "Finished replacing Xtigervnc-session."

# Create the non-root user and group, add to sudoers
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --shell /bin/bash --create-home ${USERNAME} && \
    adduser ${USERNAME} sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Verify home directory ownership and permissions
RUN echo "Verifying ${USERNAME} home directory..." && \
    ls -ld /home/${USERNAME} && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    chmod 750 /home/${USERNAME} && \
    echo "Ownership/permissions verified for /home/${USERNAME}"

# Create installer source directory owned by user
RUN mkdir -p ${INSTALLER_SOURCE_DIR} && \
    chown ${USERNAME}:${USERNAME} ${INSTALLER_SOURCE_DIR}

# Copy the installer zip file into that directory
COPY ${ZIP_FILE_REL_PATH} ${INSTALLER_SOURCE_DIR}/installer.zip

# Set the working directory TO the installer source directory
WORKDIR ${INSTALLER_SOURCE_DIR}

# Unzip the installer within this directory and remove the zip file
RUN unzip installer.zip && \
    rm installer.zip && \
    echo "Listing extracted files in ${INSTALLER_SOURCE_DIR}:" && \
    ls -l

# Verify the expected installer file exists in the current dir and make it executable
RUN if [ ! -f ${INSTALLER_RUN_FILE} ]; then \
        echo "Error: Expected installer ${INSTALLER_RUN_FILE} not found in ${INSTALLER_SOURCE_DIR}."; \
        exit 1; \
    fi && \
    chmod +x ${INSTALLER_RUN_FILE} && \
    echo "Made ${INSTALLER_RUN_FILE} executable in ${INSTALLER_SOURCE_DIR}."

# Ensure the target log directory exists BEFORE running the installer
RUN mkdir -p ${INSTALL_LOG_DIR}

# Ensure the target fonts directory exists BEFORE running the installer
RUN mkdir -p ${FONTS_DIR} && \
    echo "Ensured directory ${FONTS_DIR} exists."

# Run the installer FROM the current directory, redirecting output to the log file
RUN echo "Running installer as root from $(pwd)... Output logged to ${INSTALL_LOG_FILE}" && \
    ./${INSTALLER_RUN_FILE} > ${INSTALL_LOG_FILE} 2>&1 \
    && \
    echo "Installation finished. Check ${INSTALL_LOG_FILE} for details."

# Clean up the installer file after successful execution
RUN rm ${INSTALLER_RUN_FILE} && \
    echo "Removed installer file ${INSTALLER_RUN_FILE}."

# --- VNC/Supervisor/noVNC Setup ---
# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Copy Dante configuration
COPY danted.conf /etc/danted.conf
RUN chown ${USERNAME}:${USERNAME} /etc/danted.conf

# Copy Tinyproxy configuration
COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf

# Copy VNC startup script and Fluxbox config
COPY vnc_startup.sh /usr/local/bin/vnc_startup.sh
RUN mkdir -p /home/${USERNAME}/.fluxbox && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.fluxbox
COPY fluxbox_keys /home/${USERNAME}/.fluxbox/keys
COPY fluxbox_menu /home/${USERNAME}/.fluxbox/menu
RUN chmod +x /usr/local/bin/vnc_startup.sh && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.fluxbox/*

# Copy Dante wrapper script
COPY wait_and_start_dante.sh /usr/local/bin/wait_and_start_dante.sh
RUN chmod +x /usr/local/bin/wait_and_start_dante.sh

# Copy noVNC launch script
COPY novnc_launch.sh /usr/local/bin/novnc_launch.sh
RUN chmod +x /usr/local/bin/novnc_launch.sh

# Set final working directory to user's home
WORKDIR /home/${USERNAME}

# Expose VNC and noVNC ports
EXPOSE 5901 6901

# Run Supervisor as the main process
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# --- Optional Metadata ---
LABEL maintainer="Xavier Xiong <zx900930@gmail.com>"
LABEL version="${CLIENT_VERSION}"
LABEL description="Docker container with VNC access for Huawei UniVPN GUI Client (v${CLIENT_VERSION})"
