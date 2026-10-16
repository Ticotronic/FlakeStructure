#!/usr/bin/env bash
# Huelle um die Immich-API fuer den Quickshell-Sperrbildschirm (LockMemories.qml).
#
#   qs-immich memories <YYYY-MM-DD> [<max. Jahre zurueck>]
#       Gibt EINE Zeile JSON aus: die "An diesem Tag"-Erinnerungen, je Jahr
#       zusammengefasst, neueste zuerst, nur Fotos/Videos (max. 60 je Jahr):
#       [{"year":2025,"assets":[{"id":"...","type":"IMAGE"},...]}, ...]
#       Exit-Code != 0, wenn Immich nicht erreichbar ist (z.B. ausserhalb des
#       Heimnetzes ohne VPN) - das nutzt der Sperrbildschirm, um die Anzeige zu
#       verbergen. Exit-Code 3: das aktuelle Netz ist nicht freigegeben (s.u.),
#       es wurde gar nicht erst eine Verbindung aufgebaut.
#   qs-immich check
#       Nur die Netz-Pruefung: Exit-Code 0 = Heimnetz oder VPN, 3 = nicht freigegeben.
#   qs-immich fetch <asset-id> <zieldatei>
#       Laedt das Vorschaubild (size=preview) eines Assets in die Zieldatei.
#       Bei Videos liefert Immich das Vorschaubild des Videos.
#   qs-immich video <asset-id> <zieldatei>
#       Laedt das abspielbare Video (Immichs /video/playback) komplett in die
#       Zieldatei (max. 500 MB, max. 10 Minuten).
#
# Erwartet folgende Umgebungsvariablen (werden vom Nix-Wrapper gesetzt):
#   IMMICH_URL        z.B. http://192.168.0.145:30041
#   IMMICH_KEY_FILE   Pfad zur sops-entschluesselten API-Schluessel-Datei
#   IMMICH_JQ         Pfad zu jq
#   IMMICH_CURL       Pfad zu curl
#   IMMICH_IP         Pfad zu ip (iproute2)
#   IMMICH_IWGETID    Pfad zu iwgetid (wirelesstools)
#   IMMICH_HOME_SSIDS erlaubte Heim-WLANs, eine SSID pro Zeile
#   IMMICH_VPN_IFACES erlaubte VPN-Interfaces, durch Leerzeichen getrennt (z.B. "wg0")
# Der Schluessel braucht in Immich nur die Rechte "memory.read" und "asset.view".
set -euo pipefail

# Den Schluessel als Header ueber stdin an curl geben (-H @-), damit er nicht in
# der Prozessliste (ps) auftaucht.
api_header() {
  printf 'x-api-key: %s\n' "$(cat "${IMMICH_KEY_FILE}")"
}

# Netz-Pruefung: Der API-Schluessel geht per HTTP raus, darum nur dann, wenn wir
# sicher im Heimnetz oder im VPN sind. In einem fremden Netz mit gleichem
# Adressbereich (192.168.0.x) wuerde sonst ein fremdes Geraet den Schluessel erhalten.
#   - Weg zum Server fuehrt ueber ein VPN-Interface (IMMICH_VPN_IFACES), oder
#   - das WLAN hat eine SSID aus IMMICH_HOME_SSIDS (eine pro Zeile).
# Sonst Exit-Code 3, ganz ohne Verbindung zum Server.
network_ok() {
  local host dev ssid s v
  host="${IMMICH_URL#*://}"
  host="${host%%[:/]*}"
  dev="$("${IMMICH_IP}" -o route get "${host}" 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n 1)" || true
  [[ -n "${dev}" ]] || return 1
  for v in ${IMMICH_VPN_IFACES:-}; do
    [[ "${dev}" == "${v}" ]] && return 0
  done
  ssid="$("${IMMICH_IWGETID}" -r 2>/dev/null)" || true
  [[ -n "${ssid}" ]] || return 1
  while IFS= read -r s; do
    [[ -n "${s}" && "${s}" == "${ssid}" ]] && return 0
  done <<< "${IMMICH_HOME_SSIDS:-}"
  return 1
}

cmd="${1:-}"
case "${cmd}" in
  memories|fetch|video|check)
    network_ok || { [[ "${cmd}" == check ]] || echo "Netz nicht freigegeben (weder Heim-WLAN noch VPN)" >&2; exit 3; }
    ;;
esac
case "${cmd}" in
  check)
    # nur die Netz-Pruefung (Exit 0 = Heimnetz/VPN, 3 = nicht freigegeben), fuer den Bar-Button
    exit 0
    ;;

  memories)
    date="${2:?Datum YYYY-MM-DD fehlt}"
    back="${3:-8}"
    [[ "${date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ungueltiges Datum" >&2; exit 2; }
    [[ "${back}" =~ ^[0-9]+$ ]] || { echo "ungueltige Jahreszahl" >&2; exit 2; }
    now="${date%%-*}"

    api_header | "${IMMICH_CURL}" -fsS --connect-timeout 2 -m 10 -H @- -G \
        "${IMMICH_URL}/api/memories" \
        --data-urlencode "type=on_this_day" \
        --data-urlencode "for=${date}" \
      | "${IMMICH_JQ}" -c --argjson now "${now}" --argjson back "${back}" '
          [ .[]
            | select(.type == "on_this_day" and .data.year != null)
            | { year: .data.year,
                assets: [ .assets[] | select(.type == "IMAGE" or .type == "VIDEO") | {id, type} ] } ]
          | group_by(.year)
          | map({ year: .[0].year, assets: (map(.assets) | add | .[0:60]) })
          | map(select(.year < $now and .year >= ($now - $back) and (.assets | length) > 0))
          | sort_by(-.year)
        '
    ;;

  fetch)
    id="${2:?Asset-ID fehlt}"
    out="${3:?Zieldatei fehlt}"
    [[ "${id}" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "ungueltige Asset-ID" >&2; exit 2; }
    umask 077
    mkdir -p "$(dirname "${out}")"
    tmp="${out}.part"
    api_header | "${IMMICH_CURL}" -fsS --connect-timeout 3 -m 40 -H @- -o "${tmp}" \
        "${IMMICH_URL}/api/assets/${id}/thumbnail?size=preview"
    mv -f "${tmp}" "${out}"
    ;;

  video)
    id="${2:?Asset-ID fehlt}"
    out="${3:?Zieldatei fehlt}"
    [[ "${id}" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "ungueltige Asset-ID" >&2; exit 2; }
    umask 077
    mkdir -p "$(dirname "${out}")"
    tmp="${out}.part"
    api_header | "${IMMICH_CURL}" -fsS --connect-timeout 3 -m 600 --max-filesize 500000000 \
        -H @- -o "${tmp}" "${IMMICH_URL}/api/assets/${id}/video/playback"
    mv -f "${tmp}" "${out}"
    ;;

  *)
    echo "Aufruf: qs-immich memories <YYYY-MM-DD> [Jahre] | qs-immich check | qs-immich fetch|video <asset-id> <datei>" >&2
    exit 2
    ;;
esac
