#!/bin/bash

# File paths
GENERATOR_OUTPUT="/media/docker/compose/Invidious/generator.txt"
DOCKER_COMPOSE_FILE="/media/docker/compose/Invidious/docker-compose.yaml"
DOCKER_COMPOSE_DIR="/media/docker/compose/Invidious"
LOG_FILE="$DOCKER_COMPOSE_DIR/ipv4_visitor-data_po-token.log"

# Set DEBUG to YES or NO
DEBUG="YES"

# Function to log messages based on DEBUG setting
log_message() {
    if [[ "$DEBUG" == "YES" ]]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

# Function to get the public IP address using an external service
get_public_ipv4() {
    curl -s https://ifconfig.me
}

# Function to extract visitor_data and po_token from the output file
extract_data() {
    # Display the contents of generator.txt
    log_message "Contents of generator.txt:"
    log_message "$(cat "$GENERATOR_OUTPUT")"

    # Extract visitor_data and po_token from the file using grep with the correct format
    VISITOR_DATA=$(grep 'visitor_data:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')
    PO_TOKEN=$(grep 'po_token:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')

    # Log the extracted values
    log_message "Extracted Visitor Data: $VISITOR_DATA"
    log_message "Extracted PO Token: $PO_TOKEN"

    # Check if the values are empty and report an error
    if [[ -z "$VISITOR_DATA" || -z "$PO_TOKEN" ]]; then
        log_message "Error: visitor_data or po_token not found in generator.txt"
        exit 1
    fi
}

# Function to replace the values in the docker-compose.yaml
replace_in_docker_compose() {
    # Log the replacement process
    log_message "Replacing visitor_data and po_token in docker-compose.yaml"

    # Replace the values of visitor_data and po_token with the correct YAML format
    sed -i "s/visitor_data: .*/visitor_data: \"$VISITOR_DATA\"/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/po_token: .*/po_token: \"$PO_TOKEN\"/" "$DOCKER_COMPOSE_FILE"

    # Ensure the values have been correctly inserted
    log_message "Values replaced in docker-compose.yaml:"
    log_message "$(grep "visitor_data" "$DOCKER_COMPOSE_FILE")"
    log_message "$(grep "po_token" "$DOCKER_COMPOSE_FILE")"
}

# Function to run docker compose up -d
run_docker_compose_up() {
    cd "$DOCKER_COMPOSE_DIR" || exit
    sudo docker compose up -d

    # Log the docker compose command execution
    log_message "Docker compose up executed successfully."
}

# Function to remove the Docker container after session generation
cleanup_docker_container() {
    log_message "Cleaning up unused Docker container."
    # Get the last created container and remove it
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

# Get the public IP address when the script starts
previous_ipv4=$(get_public_ipv4)
echo "Initial Public IP: $previous_ipv4"
log_message "Initial Public IP: $previous_ipv4"

# Infinite loop to monitor IP changes
while true; do
    current_ipv4=$(get_public_ipv4)

    # If the IP has changed, run the command and update docker-compose.yaml
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
    fi

    # Wait 1 minute before checking the IP again
    sleep 60
done
