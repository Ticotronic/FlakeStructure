#!/usr/bin/env bash
# Legt Termine per CalDAV PUT auf dem Nextcloud-Kalender ab bzw. löscht sie
# per DELETE.
#
# Der zweite Parameter ist entweder:
#   - ein bloßer Dateiname ohne führenden Slash (z.B. "local-172...-4321"):
#     wird als <Kalenderpfad>/<name>.ics interpretiert. So adressieren wir
#     Termine, die WIR selbst per PUT angelegt haben (Stufe 2) — wir haben
#     den Dateinamen dabei ja selbst gewählt.
#   - ein absoluter WebDAV-Pfad mit führendem Slash (z.B.
#     "/remote.php/dav/calendars/roljon/personal/3f8b2e91-....ics"): wird
#     unverändert an NEXTCLOUD_SERVER_URL angehängt. So adressieren wir
#     Termine, die NICHT von uns angelegt wurden (z.B. über die Nextcloud-
#     Web-App) — deren realer Ressourcenpfad (href) hat i.A. NICHTS mit
#     ihrer iCalendar-UID zu tun, das muss der aus dem REPORT-Fetch bekannte
#     echte href sein (siehe NextcloudCalDAV.qml: extractHref).
#
# Erwartet dieselben Umgebungsvariablen wie nextcloud-caldav-fetch-body.sh:
#   NEXTCLOUD_SERVER_URL, NEXTCLOUD_USERNAME, NEXTCLOUD_CALENDAR_PATH,
#   NEXTCLOUD_PASSWORD_FILE
#
# Aufruf: nextcloud-caldav-push <put|delete> <uid-oder-href> [ics-body]
set -euo pipefail

ACTION="${1:?missing action (put|delete)}"
TARGET="${2:?missing target (uid or href)}"
BODY="${3:-}"

if [[ "$TARGET" == /* ]]; then
  URL="${NEXTCLOUD_SERVER_URL}${TARGET}"
else
  URL="${NEXTCLOUD_SERVER_URL}/remote.php/dav/calendars/${NEXTCLOUD_USERNAME}/${NEXTCLOUD_CALENDAR_PATH}/${TARGET}.ics"
fi
AUTH="${NEXTCLOUD_USERNAME}:$(cat "${NEXTCLOUD_PASSWORD_FILE}")"

case "$ACTION" in
  put)
    curl -s -o /dev/null -w "PUT %{http_code}\n" -X PUT \
      -H "Content-Type: text/calendar; charset=utf-8" \
      -u "$AUTH" \
      --data-binary "$BODY" \
      "$URL"
    ;;
  delete)
    curl -s -o /dev/null -w "DELETE %{http_code}\n" -X DELETE \
      -u "$AUTH" \
      "$URL"
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
