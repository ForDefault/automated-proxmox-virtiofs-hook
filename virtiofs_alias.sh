#!/bin/bash

# Capture the entire command line
command="$@"
# Directory containing VM configuration files
PROX_CONFIG_DIR="/etc/pve/qemu-server/"
ACTIVE_JSON="./active_list.json"
HOOK_JSON="./my_vms.json"
# Output JSON file
OUTPUT_JSON="./active_list.json"
# Define the log file
LOG_FILE="./error_log.txt"
VIOFSHOOK_CONF="./viofshook.conf"

# Check if the command includes 'qmstart' from UPID format
if [[ "$command" != *":qmstart:"* ]]; then
    # If the command does not include 'qmstart', execute and log it
    echo "$command" >> "$LOG_FILE"
else
    # Extract the VMID using regex to match the UPID format
    VMID=$(echo $command | grep -oP ':qmstart:\K\d+')

    # Save the entire command that was run to command_file.json
    echo "{\"command\": \"$command\", \"vmid\": \"$VMID\"}" > command_file.json

    # Remove existing active list JSON if it exists to ensure fresh setup
    [ -f "$ACTIVE_JSON" ] && rm "$ACTIVE_JSON"

    # Create a new active list JSON
    echo "{" > "$ACTIVE_JSON"
    for prox_conf in "$PROX_CONFIG_DIR"*.conf; do
        prox_id="${prox_conf##*/}"
        prox_id="${prox_id%%.conf}"
        echo "  \"$prox_id\": {" >> "$ACTIVE_JSON"
        echo "    \"HostStorage\": \"default_path\"," >> "$ACTIVE_JSON"
        echo "    \"FolderPaths\": [" >> "$ACTIVE_JSON"
        echo "      {\"tag\": \"tag1\", \"path\": \"default_path1\"}," >> "$ACTIVE_JSON"
        echo "      {\"tag\": \"tag2\", \"path\": \"default_path2\"}" >> "$ACTIVE_JSON"
        echo "    ]" >> "$ACTIVE_JSON"
        echo "  }," >> "$ACTIVE_JSON"
    done
    sed -i '$ s/},$/}/' "$ACTIVE_JSON"  # Ensure valid JSON formatting
    echo "}" >> "$ACTIVE_JSON"

    # Check if my_vms.json exists and create if not
    if [ ! -f "$HOOK_JSON" ]; then
        echo "# Placeholder for creating my_vms.json" > "$HOOK_JSON"
        echo "# This file is not created by the script but should be maintained manually if needed." >> "$HOOK_JSON"
    fi

    # Load VM data and update active_list.json accordingly
    if [ -f "$HOOK_JSON" ]; then
        jq --argjson data "$(jq '.' "$HOOK_JSON")" '. += $data' "$ACTIVE_JSON" > tmp.json && mv tmp.json "$ACTIVE_JSON"
    fi

    # Process each folder entry for the VMID
    declare -A folder_configs
    jq -c --arg VMID "$VMID" '.[$VMID].FolderPaths[]' "$ACTIVE_JSON" | while IFS= read -r folder_entry; do
        TAG=$(echo "$folder_entry" | jq -r '.tag')
        FOLDER_PATH=$(echo "$folder_entry" | jq -r '.path')
        folder_configs[$VMID]+="${TAG}=${FOLDER_PATH},"
    done

    # Write to viofshook.conf
    rm -f "$VIOFSHOOK_CONF"
    for vmid in "${!folder_configs[@]}"; do
        folder_config=$(echo "${folder_configs[$vmid]}" | sed 's/,$//') # Remove trailing comma
        echo "${vmid}:${folder_config}" >> "$VIOFSHOOK_CONF"
    done

    # Log and execute commands
    if [ -z "$VMID" ]; then
        echo "$(date +"%Y-%m-%d %I:%M:%S %p"): VMID empty in command_file.json" >> "$LOG_FILE"
    else
        HOST_STORAGE=$(jq -r --arg VMID "$VMID" '.[$VMID].HostStorage' "$ACTIVE_JSON")
        if [ "$HOST_STORAGE" == "default_path" ]; then
            echo "$(date +"%Y-%m-%d %I:%M:%S %p"): HostStorage default used, check my_vms.json" >> "$LOG_FILE"
        else
            echo "qm set \"$VMID\" --hookscript \"$HOST_STORAGE:snippets/viofshook\"" 
            echo "viofshook \"$VMID\" install" 
        fi
        eval "$(jq -r '.command' command_file.json)" 
    fi
fi
