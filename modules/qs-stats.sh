# qs-stats.sh
PREV_BAT_STATUS=""
RATE_AVG=0
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

    # Lädt der Akku gerade? ("Charging" laut sysfs-Status)
    BAT_STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)
    if [ "$BAT_STATUS" = "Charging" ]; then
        CHARGING="1"
    else
        CHARGING="0"
    fi

    # Akku-Info fuer den Tooltip: "<Zustand>;<Minuten>", z.B. "discharging;192".
    # Zustand: charging | discharging | full | plugged (Netz dran, laedt nicht) | unknown.
    # Minuten: Restlaufzeit bzw. Zeit bis voll, leer wenn (noch) nicht berechenbar.
    # Der Verbrauch (power_now bzw. current_now) schwankt stark, daher wird er ueber
    # die letzten Messungen geglaettet (gleitender Mittelwert).
    BAT_DIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
    AC_ONLINE=$(cat /sys/class/power_supply/A*/online 2>/dev/null | head -n 1)
    BAT_INFO="unknown;"
    if [ -n "$BAT_DIR" ]; then
        if [ -r "$BAT_DIR/energy_now" ]; then
            E_NOW=$(cat "$BAT_DIR/energy_now"); E_FULL=$(cat "$BAT_DIR/energy_full"); RATE=$(cat "$BAT_DIR/power_now" 2>/dev/null)
        else
            E_NOW=$(cat "$BAT_DIR/charge_now" 2>/dev/null); E_FULL=$(cat "$BAT_DIR/charge_full" 2>/dev/null); RATE=$(cat "$BAT_DIR/current_now" 2>/dev/null)
        fi
        case "$E_NOW$E_FULL$RATE" in *[!0-9]*|"") E_NOW=0; E_FULL=0; RATE=0 ;; esac
        [ -z "$RATE" ] && RATE=0
        if [ "$BAT_STATUS" != "$PREV_BAT_STATUS" ] || [ "$RATE_AVG" -le 0 ]; then
            RATE_AVG=$RATE
            PREV_BAT_STATUS=$BAT_STATUS
        else
            RATE_AVG=$(( (RATE_AVG * 7 + RATE) / 8 ))
        fi

        MINS=""
        case "$BAT_STATUS" in
            Charging)
                STATE="charging"
                if [ "$RATE_AVG" -gt 0 ] && [ "$E_FULL" -gt "$E_NOW" ]; then
                    MINS=$(( (E_FULL - E_NOW) * 60 / RATE_AVG ))
                fi
                ;;
            Discharging)
                STATE="discharging"
                if [ "$RATE_AVG" -gt 0 ]; then
                    MINS=$(( E_NOW * 60 / RATE_AVG ))
                fi
                ;;
            Full)
                STATE="full"
                ;;
            "Not charging"|Unknown)
                # Netzteil dran, aber der Akku laedt nicht: voll, oder durch eine
                # Ladegrenze (z.B. 80 %) gestoppt
                if [ "$AC_ONLINE" = "1" ] && [ "$BAT" -ge 98 ]; then STATE="full"
                elif [ "$AC_ONLINE" = "1" ]; then STATE="plugged"
                else STATE="unknown"
                fi
                ;;
            *) STATE="unknown" ;;
        esac
        # unrealistisch lange Schaetzungen (z.B. bei fast 0 Verbrauch) nicht anzeigen
        if [ -n "$MINS" ] && [ "$MINS" -gt 5999 ]; then MINS=""; fi
        BAT_INFO="$STATE;$MINS"
    fi

    # RAM (belegt/gesamt in GB, z.B. "12.3/31.9")
    RAM=$(free -m | awk '/^Speicher:/ {printf "%.1f/%.1f", $3/1024, $2/1024}')

    # CPU (Gesamtauslastung in Prozent)
    CPU=$(top -bn1 | grep -i "Cpu(s)" | awk '{printf "%.0f%%", $2 + $4}')

    # Ausgabe mit | getrennt, damit QML es leicht parsen kann
    echo "$WLAN|$BAT%|$RAM|$CPU|$CHARGING|$BAT_INFO"
    
    # 2 Sekunden warten, dann von vorn
    sleep 2
done