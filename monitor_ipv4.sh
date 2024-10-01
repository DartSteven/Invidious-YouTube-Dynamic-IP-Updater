#!/bin/bash

# File paths
GENERATOR_OUTPUT="/media/docker/compose/Invidious/generator.txt"
DOCKER_COMPOSE_FILE="/media/docker/compose/Invidious/docker-compose.yaml"
DOCKER_COMPOSE_DIR="/media/docker/compose/Invidious"


# Function to get the current IP address
get_current_ipv4() {
    ip addr show | grep -w inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1
    echo "Current IP: $(ip addr show | grep -w inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1)"
}


# Function to extract visitor_data and po_token from the output file
extract_data() {
    # Display the contents of generator.txt
    echo "Contents of generator.txt:"
    cat "$GENERATOR_OUTPUT"

    # Extract visitor_data and po_token from the file using grep with the correct format
    VISITOR_DATA=$(grep 'visitor_data:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')
    PO_TOKEN=$(grep 'po_token:' "$GENERATOR_OUTPUT" | awk -F': ' '{print $2}')

    # Debug to verify the extracted values
    echo "Extracted Visitor Data: $VISITOR_DATA"
    echo "Extracted PO Token: $PO_TOKEN"

    # Check if the values are empty and report an error
    if [[ -z "$VISITOR_DATA" || -z "$PO_TOKEN" ]]; then
        echo "Error: visitor_data or po_token not found in generator.txt"
        exit 1
    fi
}

# Function to replace the values in the docker-compose.yaml
replace_in_docker_compose() {
    # Debug to show that the correct values are being replaced
    echo "Replacing visitor_data and po_token in docker-compose.yaml"

    # Replace the values of visitor_data and po_token with the correct YAML format
    sed -i "s/visitor_data: .*/visitor_data: \"$VISITOR_DATA\"/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/po_token: .*/po_token: \"$PO_TOKEN\"/" "$DOCKER_COMPOSE_FILE"

    # Ensure the values have been correctly inserted
    echo "Values replaced in docker-compose.yaml:"
    grep "visitor_data" "$DOCKER_COMPOSE_FILE"
    grep "po_token" "$DOCKER_COMPOSE_FILE"
}

# Function to run docker compose up -d
run_docker_compose_up() {
    cd "$DOCKER_COMPOSE_DIR" || exit
    sudo docker compose up -d

    # Debug to verify that docker compose was executed
    echo "Docker compose up executed successfully."
}

# Run the replacement of the values and restart docker compose immediately
echo "Running the Docker command for the first time and updating values..."

# Run the Docker command to generate the generator.txt file
docker run quay.io/invidious/youtube-trusted-session-generator > "$GENERATOR_OUTPUT"

# Extract visitor_data and po_token
extract_data

# Replace the values in docker-compose.yaml
replace_in_docker_compose

# Run docker compose up -d
run_docker_compose_up

echo "First execution completed."

# Get the current IP address when the script starts
previous_ipv4=$(get_current_ipv4)

# Infinite loop to monitor IP changes
while true; do
    current_ipv4=$(get_current_ipv4)

    # If the IP has changed, run the command and update docker-compose.yaml
    if [[ "$current_ipv4" != "$previous_ipv4" ]]; then
        echo "IP changed from $previous_ipv4 to $current_ipv4. Running Docker command."

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

        echo "Values updated in docker-compose.yaml and docker-compose restarted."
    fi

    # Wait 1 minute before checking the IP again
    sleep 60
done
