#!/bin/bash

function ask_confirm {
    local prompt="$1"
    read -p "$prompt [Y/n]: " response
    response=${response:-Y}
    [[ "${response,,}" =~ ^(y|)$ ]]
}

# check for & install jq
function install_jq {
    if ! command -v jq &> /dev/null; then
        if ask_confirm "jq is not installed, install jq?"; then
            echo "installing jq..."
            sudo apt update > /dev/null 2>&1
            sudo apt install -y jq > /dev/null 2>&1 || {
                echo "Error while installing jq. Please install jq manually."
                exit 1
            }
        else
            exit 1
        fi
    fi
}

# get the server name
function get_server_name {
    while true; do
        read -p "Server name: " SERVER_NAME
        [[ ! -d "$SERVER_NAME" ]] && break
        echo "Server \"$SERVER_NAME\" already exists, choose a different name"
    done
}

# get the Minecraft version
function get_minecraft_version {
    while true; do
        read -p "Minecraft version: " MINECRAFT_VERSION
        [[ $MINECRAFT_VERSION =~ ^[0-9]+(\.[0-9]+)*$ ]] && break
        echo "Invalid Minecraft version, enter a valid version (e.g. 1.16, 1.17.1)"
    done
}

# query and download the build
function download_paper_jar {
    local builds_url="https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds"
    local builds_response=$(curl -s "$builds_url")

    # search for stable builds
    if ! echo "$builds_response" | jq -e 'type == "object" and has("builds")' > /dev/null; then
        echo "No builds for provided Version \"$MINECRAFT_VERSION\" found"
        exit 1
    fi

    local stable_builds=$(echo "$builds_response" | jq -r '.builds[] | select(.channel == "default") | .build')
    local latest_stable_build=$(echo "$stable_builds" | sort -n | tail -n 1)

    if [ -z "$latest_stable_build" ]; then
        echo "No stable build for Minecraft version \"$MINECRAFT_VERSION\" found."
        if ask_confirm "Do you want to look for experimental builds?"; then
            # search for unstable builds
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

    # set download link
    local jar_name="paper-$MINECRAFT_VERSION-$latest_build.jar"
    local download_url="https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds/$latest_build/downloads/$jar_name"

    # download the build
    local relative_path=${PWD/#$HOME/}
    mkdir -p "$SERVER_NAME"
    echo "Created directory \"~$relative_path/$SERVER_NAME\""
    echo
    echo "Downloading latest $build_type build for Minecraft version \"$MINECRAFT_VERSION\"..."
    local download_response=$(curl -s -w "%{http_code}" -o "$SERVER_NAME/paper.jar" "$download_url")
    if [ "$download_response" -ne 200 ]; then
        echo "Failed to download paper.jar from \"$download_url\" status_code: \"$download_response\""
        exit 1
    else
        echo "Successfully downloaded paper.jar into server directory"
        server_created=true
    fi
}

# accept EULA
function accept_eula {
    EULA_URL="https://raw.githubusercontent.com/FreakMediaLP/PaperServerSetup/main/eula.txt"
    echo
    if ask_confirm "Accept the EULA (https://aka.ms/MinecraftEULA)?"; then
        curl -fsSL "$EULA_URL" -o "$SERVER_NAME/eula.txt"
        echo "EULA accepted, downloaded eula.txt"
    else
        echo "eula=false" > "$SERVER_NAME/eula.txt"
        echo "EULA not accepted."
    fi
}

# create aliases
function create_aliases {
    echo
    if ask_confirm "Create Tmux-Aliases for easier Server-Operation?"; then
        local relative_path=${PWD/#$HOME/}
        {
            echo "# $SERVER_NAME"
            echo "alias ${SERVER_NAME}_console='tmux attach -t $SERVER_NAME'"
            echo "alias ${SERVER_NAME}_start='tmux new-session -d -s $SERVER_NAME \"cd ~$relative_path/$SERVER_NAME && java -Xms2G -Xmx6G -jar paper.jar\"'"
            echo "alias ${SERVER_NAME}_kill='tmux send-keys -t $SERVER_NAME \"stop\" Enter'"
            echo "alias ${SERVER_NAME}_restart='${SERVER_NAME}_kill && while tmux has-session -t $SERVER_NAME 2>/dev/null; do sleep 1; done && ${SERVER_NAME}_start'"
            echo
        } > ~/.bashrc.tmp
        cat ~/.bashrc >> ~/.bashrc.tmp
        mv ~/.bashrc.tmp ~/.bashrc

        source ~/.bashrc  # apply aliases

        echo "Added following Aliases (make sure to install tmux)"
        echo
        echo "${SERVER_NAME}_console:   opens server console (tmux session)"
        echo "${SERVER_NAME}_start:     starts server (with provided RAM limits)"
        echo "${SERVER_NAME}_kill:      stops server (kill only used for easier naming)"
        echo "${SERVER_NAME}_restart:   stops & starts server"
        echo
    else
        echo "No Aliases created"
    fi
}

# initial setup logic
server_created=false
install_jq
get_server_name
get_minecraft_version
download_paper_jar

if [ "$server_created" = true ]; then
    accept_eula
    create_aliases
fi