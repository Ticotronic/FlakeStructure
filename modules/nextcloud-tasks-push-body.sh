#!/usr/bin/env bash
# Legt Aufgaben (VTODO) per CalDAV PUT in einer Nextcloud-Taskliste ab bzw.
# loescht sie per DELETE.
#
# Anders als beim Kalender-Pendant (nextcloud-caldav-push) gibt es hier keine
# einzelne feste Taskliste - der Nutzer kann mehrere Listen haben (siehe
# nextcloud-tasks-discover). Deshalb ist der <href>-Parameter hier IMMER ein
# vollstaendiger, absoluter WebDAV-Pfad:
#   - beim Anlegen: <listHref><neue-uid>.ics (die QML-Seite waehlt den
#     Dateinamen selbst, analog zum Kalender-Fall fuer selbst angelegte
#     Termine)
#   - beim Bearbeiten/Loeschen einer bestehenden Aufgabe: der echte href, wie
#     er beim REPORT-Fetch geliefert wurde (NextcloudTasksDAV.qml: extractHref)
#
# Erwartet: NEXTCLOUD_SERVER_URL, NEXTCLOUD_USERNAME, NEXTCLOUD_PASSWORD_FILE
#
# Aufruf: nextcloud-tasks-push <put|delete> <href> [ics-body]
set -euo pipefail

ACTION="${1:?missing action (put|delete)}"
HREF="${2:?missing href}"
BODY="${3:-}"

URL="${NEXTCLOUD_SERVER_URL}${HREF}"
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
