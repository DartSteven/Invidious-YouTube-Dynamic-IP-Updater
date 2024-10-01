# Invidious IPv4 Change - YouTube Trusted Session Generator

This repository provides a Bash script that monitors changes in the public IPv4 address and automatically updates the `visitor_data` and `po_token` fields in the Invidious Docker Compose configuration. It uses the YouTube Trusted Session Generator to retrieve fresh credentials whenever the public IP changes and seamlessly restarts the Invidious Docker container with the new values.

## Features

- **Automatic Public IP Monitoring**: Continuously checks for changes in the public IPv4 address using external services.
- **Session Token Update**: Automatically generates new `visitor_data` and `po_token` using the YouTube Trusted Session Generator.
- **Docker Integration**: Updates the `docker-compose.yaml` file and restarts the Invidious container to apply the new tokens.
- **Systemd Service Support**: Runs as a `systemd` service, ensuring the script is started on boot and keeps running in the background.

## Prerequisites

- Docker installed and running on your system.
- The Invidious Docker Compose setup.
- YouTube Trusted Session Generator Docker image (`quay.io/invidious/youtube-trusted-session-generator`).

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Invidious-ipv4change-youtube-trusted-session-generator.git
cd Invidious-ipv4change-youtube-trusted-session-generator
```

### 2. Configure the `monitor_ipv4.sh` Script

The script is located at `/media/docker/compose/Invidious/monitor_ipv4.sh`. This script monitors your public IPv4 address and updates the necessary credentials in your `docker-compose.yaml` file.

Ensure that the paths in the script match your Docker Compose directory and the file paths on your system.

### 3. Set up the Systemd Service

You can configure the script to run automatically using systemd. Here's how:

1. Create a service file at `/etc/systemd/system/monitor_ipv4.service`:

    ```bash
    sudo nano /etc/systemd/system/monitor_ipv4.service
    ```

2. Add the following content:

    ```ini
    [Unit]
    Description=Monitor IP changes and update docker-compose environment
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStart=/media/docker/compose/Invidious/monitor_ipv4.sh
    Restart=always
    WorkingDirectory=/media/docker/compose/Invidious

    [Install]
    WantedBy=multi-user.target
    ```

3. Reload `systemd` and enable the service:

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable monitor_ipv4.service
    ```

4. Start the service:

    ```bash
    sudo systemctl start monitor_ipv4.service
    ```

You can check the service's status with:

```bash
sudo systemctl status monitor_ipv4.service
```

### 4. Logs

The script generates logs that track IP changes, the extracted `visitor_data` and `po_token`, and Docker restarts. Logs are saved in `/media/docker/compose/Invidious/ipv4_visitor-data_po-token.log`.

### 5. Docker Compose Setup

Ensure your `docker-compose.yaml` file is correctly set up to include the following environment variables under the Invidious container's configuration:

```yaml
services:
  invidious:
    ...
    environment:
      INVIDIOUS_CONFIG: |
        ...
        visitor_data: "YourVisitorDataHere"
        po_token: "YourPoTokenHere"
```

The script will automatically update these values whenever the public IP changes.

## How It Works

1. **IP Monitoring**: The script uses `curl` to monitor the public IP address from an external service like `ifconfig.me`.
2. **Session Generation**: When an IP change is detected, the script runs the YouTube Trusted Session Generator to fetch new `visitor_data` and `po_token`.
3. **Docker Compose Update**: The script updates the `docker-compose.yaml` file with the new values and restarts the Invidious container.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
