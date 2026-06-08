# qs-stats.sh
while true; do
    # WLAN (SSID auslesen, falls nicht verbunden: 'Offline')
    WLAN_SSID=$(iwgetid -r)
  
    if [ -z "$WLAN_SSID" ]; then
            WLAN="󰤭 Offline"
    else
            # nmcli liest die Netzwerke aus, awk filtert die Zeile mit dem Sternchen (*) = das aktive Netz
            SIGNAL=$(nmcli -t -f IN-USE,SIGNAL dev wifi | awk -F: '/^\*/{print $2}' | head -n1)
            
            # Icon anhand der Prozentzahl (0-100) auswählen
            if [ -z "$SIGNAL" ]; then ICON="󰤯"
            elif [ "$SIGNAL" -ge 80 ]; then ICON="󰤨"
            elif [ "$SIGNAL" -ge 60 ]; then ICON="󰤥"
            elif [ "$SIGNAL" -ge 40 ]; then ICON="󰤢"
            elif [ "$SIGNAL" -ge 20 ]; then ICON="󰤟"
            else ICON="󰤯"
            fi
            
            # Fertigen String zusammensetzen
            WLAN="$ICON $WLAN_SSID"
    fi

    # Akku (Sucht nach der Batterie, nimmt den ersten Treffer)
    BAT=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1)
    [ -z "$BAT" ] && BAT="100" # Fallback, falls mal kein Akku gefunden wird
    
    # RAM (Verwendet in GB)
    RAM=$(free -m | awk '/^Speicher:/ {printf "%.1f%%", $3/$2 * 100}')
    
    # CPU (Gesamtauslastung in Prozent)
    CPU=$(top -bn1 | grep -i "Cpu(s)" | awk '{printf "%.0f%%", $2 + $4}')
    
    # Ausgabe mit | getrennt, damit QML es leicht parsen kann
    echo "$WLAN|$BAT%|$RAM|$CPU"
    
    # 2 Sekunden warten, dann von vorn
    sleep 2
done