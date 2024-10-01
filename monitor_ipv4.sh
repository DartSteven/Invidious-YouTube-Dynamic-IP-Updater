#!/bin/bash

# File paths
GENERATOR_OUTPUT="/media/docker/compose/Invidious/generator.txt"
DOCKER_COMPOSE_FILE="/media/docker/compose/Invidious/docker-compose.yaml"
DOCKER_COMPOSE_DIR="/media/docker/compose/Invidious"
LOG_FILE="$DOCKER_COMPOSE_DIR/ipv4_visitor-data_po-token.log"

# Function to get the public IP address using an external service
get_public_ipv4() {
    curl -s https://ifconfig.me
}

# Function to extract visitor_data and po_token from the output file
extract_data() {
    # Display the contents of generator.txt
    echo "Contents of generator.txt:" >> "$LOG_FILE"
    cat "$GENERATOR_OUTPUT" >> "$LOG_FILE"

    # Extract visitor_data and po_token from the file using grep with the correct format
    VISITOR_DATA=$(grep 'visitor_data:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')
    PO_TOKEN=$(grep 'po_token:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')

    # Log the extracted values
    echo "Extracted Visitor Data: $VISITOR_DATA" >> "$LOG_FILE"
    echo "Extracted PO Token: $PO_TOKEN" >> "$LOG_FILE"

    # Check if the values are empty and report an error
    if [[ -z "$VISITOR_DATA" || -z "$PO_TOKEN" ]]; then
        echo "Error: visitor_data or po_token not found in generator.txt" >> "$LOG_FILE"
        exit 1
    fi
}

# Function to replace the values in the docker-compose.yaml
replace_in_docker_compose() {
    # Log the replacement process
    echo "Replacing visitor_data and po_token in docker-compose.yaml" >> "$LOG_FILE"

    # Replace the values of visitor_data and po_token with the correct YAML format
    sed -i "s/visitor_data: .*/visitor_data: \"$VISITOR_DATA\"/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/po_token: .*/po_token: \"$PO_TOKEN\"/" "$DOCKER_COMPOSE_FILE"

    # Ensure the values have been correctly inserted
    echo "Values replaced in docker-compose.yaml:" >> "$LOG_FILE"
    grep "visitor_data" "$DOCKER_COMPOSE_FILE" >> "$LOG_FILE"
    grep "po_token" "$DOCKER_COMPOSE_FILE" >> "$LOG_FILE"
}

# Function to run docker compose up -d
run_docker_compose_up() {
    cd "$DOCKER_COMPOSE_DIR" || exit
    sudo docker compose up -d

    # Log the docker compose command execution
    echo "Docker compose up executed successfully." >> "$LOG_FILE"
}

# Run the replacement of the values and restart docker compose immediately
echo "Running the Docker command for the first time and updating values..." >> "$LOG_FILE"

# Run the Docker command to generate the generator.txt file
docker run quay.io/invidious/youtube-trusted-session-generator > "$GENERATOR_OUTPUT"

# Extract visitor_data and po_token
extract_data

# Replace the values in docker-compose.yaml
replace_in_docker_compose

# Run docker compose up -d
run_docker_compose_up

echo "First execution completed." >> "$LOG_FILE"

# Get the public IP address when the script starts
previous_ipv4=$(get_public_ipv4)
echo "Initial Public IP: $previous_ipv4" >> "$LOG_FILE"

# Infinite loop to monitor IP changes
while true; do
    current_ipv4=$(get_public_ipv4)
    echo "Current Public IP: $current_ipv4" >> "$LOG_FILE"

    # If the IP has changed, run the command and update docker-compose.yaml
    if [[ "$current_ipv4" != "$previous_ipv4" ]]; then
        echo "Public IP changed from $previous_ipv4 to $current_ipv4. Running Docker command." >> "$LOG_FILE"

        # Run the Docker command to generate the generator.txt file
        docker run quay.io/invidious/youtube-trusted-session-generator > "$GENERATOR_OUTPUT"

        # Extract visitor_data and po_token
        extract_data

        # Replace the values in docker-compose.yaml
        replace_in_docker_compose

        # Run docker compose up -d
        run_docker_compose_up

        # Update the previous IP
        previous_ipv4="$current_ipv4"

        echo "Values updated in docker-compose.yaml and docker-compose restarted." >> "$LOG_FILE"
    fi

    # Wait 1 minute before checking the IP again
    sleep 60
done
