#!/bin/bash

# Configuración
DB_PATH="/media/frigate/backups"
RECORDINGS_PATH="/media/frigate/recordings"
USB_PATH="/mnt/router_usb/"
DAYS_TO_KEEP=1

# Obtener la fecha actual
TODAY=$(date +%Y-%m-%d)

# Crear una copia de seguridad de la base de datos
echo "Creando copia de seguridad de la base de datos..."
sqlite3 "/home/pan/frigate/config/frigate.db" ".backup '$DB_PATH/frigate_$(date +%Y-%m-%d_%H-%M).db'"

# Limpiar backups antiguos
echo "Eliminando backups antiguos..."
find "$DB_PATH" -name "frigate_*.db" -mtime +$DAYS_TO_KEEP -exec rm {} \;

# Seleccionar la copia más reciente
LATEST_DB=$(ls -t $DB_PATH/frigate_*.db | head -n 1)

if [ -z "$LATEST_DB" ]; then
    echo "No se encontró ninguna base de datos de respaldo. Saliendo..."
    exit 1
fi

echo "Base de datos seleccionada: $LATEST_DB"

# Verificar si la USB está montada
if [ ! -d "$USB_PATH" ]; then
    echo "El directorio USB no está montado. Saliendo..."
    exit 1
fi

# Crear carpeta con la fecha del día
DATE_FOLDER="$USB_PATH/Recordings/$TODAY"
mkdir -p "$DATE_FOLDER"

echo "Buscando alertas en la base de datos..."
ALERTS=$(sqlite3 "$LATEST_DB" "SELECT id, camera, datetime(start_time, 'unixepoch'), datetime(end_time, 'unixepoch'), has_clip FROM event WHERE date(datetime(start_time, 'unixepoch')) = date('now');")

if [ -z "$ALERTS" ]; then
    echo "No se encontraron alertas para hoy. Saliendo..."
    exit 0
fi

echo "Alertas encontradas:"
echo "$ALERTS"

# Función para buscar el vídeo más cercano
buscar_video_cercano() {
    local path=$1
    local target_time=$2
    local before=$3  # "true" para buscar antes, "false" para buscar después

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

# Procesar cada alerta
IFS=$'\n'
for ALERT in $ALERTS; do
    ID=$(echo $ALERT | cut -d '|' -f 1)
    CAMERA=$(echo $ALERT | cut -d '|' -f 2)
    START_TIME=$(echo $ALERT | cut -d '|' -f 3)
    END_TIME=$(echo $ALERT | cut -d '|' -f 4)
    HAS_CLIP=$(echo $ALERT | cut -d '|' -f 5)

    if [ "$HAS_CLIP" -eq 1 ]; then
        echo "Procesando alerta ID: $ID"
        echo "Cámara: $CAMERA"
        echo "Inicio: $START_TIME"
        echo "Fin: $END_TIME"

        ALERT_PATH="$DATE_FOLDER/$ID"
        mkdir -p "$ALERT_PATH"

        CLIPS_PATH="$RECORDINGS_PATH/$(date -d "$START_TIME" +%Y-%m-%d)/$(date -d "$START_TIME" +%H)/$CAMERA"
        echo "Buscando vídeos en: $CLIPS_PATH"

        DURATION=$(( $(date -d "$END_TIME" +%s) - $(date -d "$START_TIME" +%s) ))
        FRAGMENTS=$(( (DURATION / 10) + 2 ))

        FRAGMENT_LIST=()
        CURRENT_TIME="$START_TIME"
        for (( i=0; i<$FRAGMENTS; i++ )); do
            FRAGMENT=$(buscar_video_cercano "$CLIPS_PATH" "$CURRENT_TIME" true)
            if [ -n "$FRAGMENT" ]; then
                FRAGMENT_LIST+=("$FRAGMENT")
            fi
            CURRENT_TIME=$(date -d "$CURRENT_TIME 10 seconds" +"%H:%M:%S")
        done

        if [ ${#FRAGMENT_LIST[@]} -gt 0 ]; then
            echo "Fragmentos encontrados:"
            printf '%s\n' "${FRAGMENT_LIST[@]}"
            echo "Copiando fragmentos al USB con rsync..."
            for FRAGMENT in "${FRAGMENT_LIST[@]}"; do
                rsync -av "$FRAGMENT" "$ALERT_PATH/"
            done
            sync  # Asegurar que se escriban los datos antes de continuar
            echo "Alerta $ID copiada con ${#FRAGMENT_LIST[@]} fragmentos en $ALERT_PATH"
        else
            echo "No se encontraron vídeos cercanos para la alerta $ID."
        fi
    fi
    echo "--------------------------------------"
done

echo "Proceso completado."
