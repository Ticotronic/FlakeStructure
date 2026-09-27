#!/usr/bin/env bash
# Legt lokal erstellte/geänderte Termine per CalDAV PUT auf dem Nextcloud-
# Kalender ab, bzw. löscht sie per DELETE. Wird nur für lokal erzeugte
# Termine aufgerufen (UID-Präfix "local-"), niemals für von Nextcloud
# gelesene Termine (die bleiben schreibgeschützt, siehe Stufe 1).
#
# Erwartet dieselben Umgebungsvariablen wie nextcloud-caldav-fetch-body.sh:
#   NEXTCLOUD_SERVER_URL, NEXTCLOUD_USERNAME, NEXTCLOUD_CALENDAR_PATH,
#   NEXTCLOUD_PASSWORD_FILE
#
# Aufruf: nextcloud-caldav-push <put|delete> <uid> [ics-body]
set -euo pipefail

ACTION="${1:?missing action (put|delete)}"
UID_ARG="${2:?missing uid}"
BODY="${3:-}"

URL="${NEXTCLOUD_SERVER_URL}/remote.php/dav/calendars/${NEXTCLOUD_USERNAME}/${NEXTCLOUD_CALENDAR_PATH}/${UID_ARG}.ics"
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
