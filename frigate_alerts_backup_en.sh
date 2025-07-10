#!/bin/bash

# Configuration
DB_PATH="/media/frigate/backups"
RECORDINGS_PATH="/media/frigate/recordings"
USB_PATH="/mnt/router_usb/"
DAYS_TO_KEEP=1

# Get current date
TODAY=$(date +%Y-%m-%d)

# Create a database backup
echo "Creating database backup..."
sqlite3 "/home/pan/frigate/config/frigate.db" ".backup '$DB_PATH/frigate_$(date +%Y-%m-%d_%H-%M).db'"

# Clean old backups
echo "Removing old backups..."
find "$DB_PATH" -name "frigate_*.db" -mtime +$DAYS_TO_KEEP -exec rm {} \;

# Select the most recent backup
LATEST_DB=$(ls -t $DB_PATH/frigate_*.db | head -n 1)

if [ -z "$LATEST_DB" ]; then
    echo "No backup database found. Exiting..."
    exit 1
fi

echo "Selected database: $LATEST_DB"

# Check if USB is mounted
if [ ! -d "$USB_PATH" ]; then
    echo "USB directory is not mounted. Exiting..."
    exit 1
fi

echo "Looking for alerts in the database..."
ALERTS=$(sqlite3 "$LATEST_DB" "SELECT id, camera, datetime(start_time, 'unixepoch'), datetime(end_time, 'unixepoch'), has_clip FROM event WHERE date(datetime(start_time, 'unixepoch')) = date('now');")

if [ -z "$ALERTS" ]; then
    echo "No alerts found for today. Exiting..."
    exit 0
fi

echo "Alerts found:"
echo "$ALERTS"

# Function to find the closest video fragment
find_closest_video() {
    local path=$1
    local target_time=$2
    local before=$3  # "true" to find before, "false" to find after

    target_mm_ss=$(echo "$target_time" | awk -F: '{print $2 "." $3}')
    best_match=""

    for file in $(ls "$path"/*.mp4 2>/dev/null | sort -V); do
        file_time=$(basename "$file" .mp4)
        file_seconds=$((10#$(echo "$file_time" | awk -F. '{print ($1 * 60) + $2}') ))
        target_seconds=$((10#$(echo "$target_mm_ss" | awk -F. '{print ($1 * 60) + $2}') ))

        if $before; then
            if [[ $file_seconds -le $target_seconds ]]; then
                best_match="$file"
            else
                break
            fi
        else
            if [[ $file_seconds -ge $target_seconds ]]; then
                best_match="$file"
                break
            fi
        fi
    done

    echo "$best_match"
}

# Process each alert
IFS=$'\n'
for ALERT in $ALERTS; do
    ID=$(echo $ALERT | cut -d '|' -f 1)
    CAMERA=$(echo $ALERT | cut -d '|' -f 2)
    START_TIME=$(echo $ALERT | cut -d '|' -f 3)
    END_TIME=$(echo $ALERT | cut -d '|' -f 4)
    HAS_CLIP=$(echo $ALERT | cut -d '|' -f 5)

    if [ "$HAS_CLIP" -eq 1 ]; then
        echo "Processing alert ID: $ID"
        echo "Camera: $CAMERA"
        echo "Start: $START_TIME"
        echo "End: $END_TIME"

        # Extract start hour
        HOUR=$(date -d "$START_TIME" +%H)

        # Define correct Frigate path
        ALERT_PATH="$USB_PATH/Recordings/$TODAY/$HOUR/$CAMERA"
        mkdir -p "$ALERT_PATH"

        CLIPS_PATH="$RECORDINGS_PATH/$(date -d "$START_TIME" +%Y-%m-%d)/$HOUR/$CAMERA"
        echo "Searching for videos in: $CLIPS_PATH"

        DURATION=$(( $(date -d "$END_TIME" +%s) - $(date -d "$START_TIME" +%s) ))
        FRAGMENTS=$(( (DURATION / 10) + 2 ))

        FRAGMENT_LIST=()
        CURRENT_TIME="$START_TIME"
        for (( i=0; i<$FRAGMENTS; i++ )); do
            FRAGMENT=$(find_closest_video "$CLIPS_PATH" "$CURRENT_TIME" true)
            if [ -n "$FRAGMENT" ]; then
                FRAGMENT_LIST+=("$FRAGMENT")
            fi
            CURRENT_TIME=$(date -d "$CURRENT_TIME 10 seconds" +"%H:%M:%S")
        done

        if [ ${#FRAGMENT_LIST[@]} -gt 0 ]; then
            echo "Fragments found:"
            printf '%s\n' "${FRAGMENT_LIST[@]}"
            echo "Copying fragments to USB with rsync..."
            for FRAGMENT in "${FRAGMENT_LIST[@]}"; do
                rsync -av "$FRAGMENT" "$ALERT_PATH/"
            done
            sync  # Ensure data is written before continuing
            echo "Alert $ID copied with ${#FRAGMENT_LIST[@]} fragments to $ALERT_PATH"
        else
            echo "No matching videos found for alert $ID."
        fi
    fi
    echo "--------------------------------------"
done

echo "Process completed."
