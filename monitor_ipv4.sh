#!/bin/bash

# File paths
GENERATOR_OUTPUT="/media/docker/compose/Invidious/generator.txt"
DOCKER_COMPOSE_FILE="/media/docker/compose/Invidious/docker-compose.yaml"
DOCKER_COMPOSE_DIR="/media/docker/compose/Invidious"
LOG_FILE="$DOCKER_COMPOSE_DIR/ipv4_visitor-data_po-token.log"

# Set DEBUG to YES or NO
DEBUG="YES"
no_internet_since=""

# Function to log messages with date and time
log_message() {
    local timestamp
    timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
    if [[ "$DEBUG" == "YES" ]]; then
        echo "$timestamp $1" >> "$LOG_FILE"
    fi
}

# Function to check if the monitor_ipv4.service is active and log its status
check_service_status() {
    service_status=$(systemctl is-active monitor_ipv4.service)
    if [[ "$service_status" == "active" ]]; then
        log_message "monitor_ipv4.service is active and running."
    else
        log_message "monitor_ipv4.service is not active. Current status: $service_status"
    fi
}

# Function to check for internet connectivity using ping to a reliable external server
check_internet_connection() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        if [[ -n "$no_internet_since" ]]; then
            log_message "Internet connected, new IP: $(get_public_ipv4)"
            no_internet_since=""
        fi
        return 0
    else
        if [[ -z "$no_internet_since" ]]; then
            no_internet_since=$(date '+[%Y-%m-%d %H:%M:%S]')
            log_message "No connection to internet since $no_internet_since"
        fi
        return 1
    fi
}

# Function to get the public IP address using an external service
get_public_ipv4() {
    curl -s https://ifconfig.me
}

# Function to extract visitor_data and po_token from the output file
extract_data() {
    log_message "Contents of generator.txt:"
    log_message "$(cat "$GENERATOR_OUTPUT")"

    VISITOR_DATA=$(grep 'visitor_data:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')
    PO_TOKEN=$(grep 'po_token:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')

    log_message "Extracted Visitor Data: $VISITOR_DATA"
    log_message "Extracted PO Token: $PO_TOKEN"

    if [[ -z "$VISITOR_DATA" || -z "$PO_TOKEN" ]]; then
        log_message "Error: visitor_data or po_token not found in generator.txt"
        exit 1
    fi
}

# Function to replace the values in the docker-compose.yaml
replace_in_docker_compose() {
    log_message "Replacing visitor_data and po_token in docker-compose.yaml"

    sed -i "s/visitor_data: .*/visitor_data: \"$VISITOR_DATA\"/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/po_token: .*/po_token: \"$PO_TOKEN\"/" "$DOCKER_COMPOSE_FILE"

    log_message "Values replaced in docker-compose.yaml:"
    log_message "$(grep "visitor_data" "$DOCKER_COMPOSE_FILE")"
    log_message "$(grep "po_token" "$DOCKER_COMPOSE_FILE")"
}

# Function to run docker compose up -d
run_docker_compose_up() {
    cd "$DOCKER_COMPOSE_DIR" || exit
    sudo docker compose up -d

    log_message "Docker compose up executed successfully."
}

# Function to remove the Docker container after session generation
cleanup_docker_container() {
    log_message "Cleaning up unused Docker container."
    container_id=$(sudo docker ps -a -q --filter "ancestor=quay.io/invidious/youtube-trusted-session-generator" --format="{{.ID}}" | tail -n 1)
    
    if [ -n "$container_id" ]; then
        sudo docker rm "$container_id" >> "$LOG_FILE"
        log_message "Removed container: $container_id"
    else
        log_message "No container found for cleanup."
    fi
}

# Run the replacement of the values and restart docker compose immediately
log_message "Running the Docker command for the first time and updating values..."
check_service_status

# Run the Docker command to generate the generator.txt file
sudo docker run quay.io/invidious/youtube-trusted-session-generator > "$GENERATOR_OUTPUT"

# Extract visitor_data and po_token
extract_data

# Replace the values in docker-compose.yaml
replace_in_docker_compose

# Run docker compose up -d
run_docker_compose_up

# Clean up the Docker container
cleanup_docker_container

log_message "First execution completed."
check_service_status

# Get the public IP address when the script starts
previous_ipv4=$(get_public_ipv4)
echo "Initial Public IP: $previous_ipv4"
log_message "Initial Public IP: $previous_ipv4"

# Infinite loop to monitor IP changes
while true; do
    if check_internet_connection; then
        current_ipv4=$(get_public_ipv4)

        if [[ "$current_ipv4" != "$previous_ipv4" ]]; then
            echo "Public IP changed from $previous_ipv4 to $current_ipv4. Running Docker command."
            log_message "Public IP changed from $previous_ipv4 to $current_ipv4."

            # Run the Docker command to generate the generator.txt file
            sudo docker run quay.io/invidious/youtube-trusted-session-generator > "$GENERATOR_OUTPUT"

            # Extract visitor_data and po_token
            extract_data

            # Replace the values in docker-compose.yaml
            replace_in_docker_compose

            # Run docker compose up -d
            run_docker_compose_up

            # Clean up the Docker container
            cleanup_docker_container

            # Update the previous IP
            previous_ipv4="$current_ipv4"

            log_message "Values updated in docker-compose.yaml and docker-compose restarted."
            check_service_status
        fi
    fi

    # Wait 1 minute before checking the IP again
    sleep 60
done
