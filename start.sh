#!/bin/bash

function send_request {
    local url=$1
    response=$(curl -s --write-out "%{http_code}" --output /dev/null "$url")
    echo "$response"
}

function download_build {
    local file_version=$1
    local build=$2
    local papermc_url="https://api.papermc.io/v2/projects/paper/versions/${file_version}/builds/${build}/downloads/paper.jar"

    echo "Downloading paper.jar for Minecraft version \"$file_version\" latest build [$build]..."
    curl -o paper.jar "$papermc_url"

    if [ $? -eq 0 ]; then
        echo "Successfully downloaded paper.jar"
    else
        echo "Failed to download paper.jar from \"$papermc_url\""
    fi
}

read -p "Minecraft version: " minecraft_version
response=$(send_request "https://api.papermc.io/v2/projects/paper/versions/${minecraft_version}/builds")

if [ "$response" == "200" ]; then
    builds=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${minecraft_version}/builds" | jq -r '.builds[] | select(.channel == "default") | .build')
    latest_build=$(echo "$builds" | tail -n 1)

    if [ -n "$latest_build" ]; then
        download_build "$minecraft_version" "$latest_build"
    else
        echo "No stable build for Minecraft version \"$minecraft_version\" found"
        read -p "Do you want to look for experimental builds? (Y/n): " search_experimental
        if [[ -z "$search_experimental" || "$search_experimental" =~ ^[Yy]$ ]]; then
            experimental_builds=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${minecraft_version}/builds" | jq -r '.builds[] | select(.channel == "experimental") | .build')
            latest_experimental_build=$(echo "$experimental_builds" | tail -n 1)

            if [ -n "$latest_experimental_build" ]; then
                echo "Experimental build for Minecraft version \"$minecraft_version\" found"
                download_build "$minecraft_version" "$latest_experimental_build"
            else
                echo "No experimental build for Minecraft version \"$minecraft_version\" found"
            fi
        fi
    fi
else
    echo "Unable to request builds for Minecraft version \"$minecraft_version\" status_code: $response"
fi