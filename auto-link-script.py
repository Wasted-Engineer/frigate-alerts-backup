import paho.mqtt.client as mqtt
import json
import time
import subprocess

# Configuración del broker MQTT
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "frigate/events"

# Función que se ejecuta cuando llega un mensaje MQTT
def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())  # Decodificar JSON
        if payload.get("type") == "end":  # Solo actuar al final del evento
            camera = payload["after"]["camera"]
            event_id = payload["after"]["id"]
            
            print(f"Evento terminado en cámara: {camera}, ID: {event_id}")
            print("Esperando 5 segundos para que Frigate genere el clip...")
            time.sleep(5)

            # Ejecutar el script de backup (ajustar la ruta según sea necesario)
            subprocess.run(["/media/frigate/backups/frigate_alerts_backup.sh", camera, event_id])

    except Exception as e:
        print(f"Error procesando el mensaje: {e}")

# Configurar el cliente MQTT
client = mqtt.Client()
client.on_message = on_message
client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.subscribe(MQTT_TOPIC)

# Mantener el script corriendo
print("Escuchando eventos de Frigate...")
client.loop_forever()
