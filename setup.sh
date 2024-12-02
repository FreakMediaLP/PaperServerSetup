#!/bin/bash

# Function to get the server name
function get_server_name {
    while true; do
        read -p "Server name: " SERVER_NAME
        if [ ! -d "$SERVER_NAME" ]; then
            break
        else
            echo "Server \"$SERVER_NAME\" already exists, chose a different name"
        fi
    done
}

# Function to get the Minecraft version
function get_minecraft_version {
    while true; do
        read -p "Minecraft version: " MINECRAFT_VERSION
        if [[ $MINECRAFT_VERSION =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
            break
        else
            echo "Invalid Minecraft version, enter a valid version (e.g. 1.16, 1.17.1)"
        fi
    done
}

# Function to query and download the build
function download_paper_jar {
    local builds_url="https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds"
    local builds_response=$(curl -s "$builds_url")

    # Search for stable builds
    if ! echo "$builds_response" | jq -e 'type == "object" and has("builds")' > /dev/null; then
        echo "No builds for provided Version \"$MINECRAFT_VERSION\" found"
        exit 1
    fi

    # Suche nach stabilen Builds
    local stable_builds=$(echo "$builds_response" | jq -r '.builds[] | select(.channel == "default") | .build')
    local latest_stable_build=$(echo "$stable_builds" | sort -n | tail -n 1)

    if [ -z "$latest_stable_build" ]; then
        echo "No stable build for Minecraft version \"$MINECRAFT_VERSION\" found."
        read -p "Do you want to look for experimental builds? [Y/n] " response
        if [[ ! "$response" =~ ^[nN]$ ]]; then
            # Suche nach experimentellen Builds
            local experimental_builds=$(echo "$builds_response" | jq -r '.builds[] | select(.channel == "experimental") | .build')
            local latest_experimental_build=$(echo "$experimental_builds" | sort -n | tail -n 1)
            if [ -z "$latest_experimental_build" ]; then
                echo "No experimental build for Minecraft version \"$MINECRAFT_VERSION\" found."
                exit 1
            fi
            latest_build=$latest_experimental_build
            build_type="experimental"
        else
            exit 1
        fi
    else
        latest_build=$latest_stable_build
        build_type="stable"
        echo "Build for Minecraft version \"$MINECRAFT_VERSION\" found."
    fi

    local jar_name="paper-$MINECRAFT_VERSION-$latest_build.jar"
    local download_url="https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds/$latest_build/downloads/$jar_name"

    # Save user directory
    local user_home=$(eval echo ~$USER)
    # Absolute path without user directory
    local relative_path=${PWD/#$user_home/}
    mkdir -p "$SERVER_NAME"

    echo "Created directory \"$relative_path/$SERVER_NAME\""

    echo
    echo "Downloading latest $build_type build for Minecraft version \"$MINECRAFT_VERSION\"..."
    local download_response=$(curl -s -w "%{http_code}" -o "$SERVER_NAME/paper.jar" "$download_url")

    if [ "$download_response" -ne 200 ]; then
        echo "Failed to download paper.jar from \"$download_url\" status_code: \"$download_response\""
        exit 1
    else
        echo "Successfully downloaded paper.jar into server directory"
        accept_eula
    fi
}

# Function to accept EULA
function accept_eula {
    read -p "Accept the EULA (https://aka.ms/MinecraftEULA) [Y/n]: " accept
    accept=${accept:-Y}  
    if [[ "$accept" =~ ^[Yy]$ ]]; then
        echo "eula=true" > "$SERVER_NAME/eula.txt"
        echo "EULA accepted, created eula.txt"
    else
        echo "eula=false" > "$SERVER_NAME/eula.txt"
        echo "EULA not accepted, exiting."
        exit 1
    fi
}

# Main script logic
get_server_name
get_minecraft_version

# Download the Paper JAR
download_paper_jar
