#!/usr/bin/env bash
# Ruft alle VEVENTs im Zeitfenster [-31 Tage, +180 Tage] per CalDAV REPORT ab.
# Erwartet folgende Umgebungsvariablen (werden vom Nix-Wrapper gesetzt):
#   NEXTCLOUD_SERVER_URL      z.B. https://cloud.example.com
#   NEXTCLOUD_USERNAME        Nextcloud-Benutzername
#   NEXTCLOUD_CALENDAR_PATH   URL-Segment des Kalenders (s. Setup-Hinweis)
#   NEXTCLOUD_PASSWORD_FILE   Pfad zur sops-entschlüsselten App-Passwort-Datei
set -euo pipefail

START=$(date -u -d "-31 days" +"%Y%m%dT000000Z")
END=$(date -u -d "+180 days" +"%Y%m%dT000000Z")

curl -s -X REPORT \
  -H "Depth: 1" \
  -H "Content-Type: application/xml; charset=utf-8" \
  -u "${NEXTCLOUD_USERNAME}:$(cat "${NEXTCLOUD_PASSWORD_FILE}")" \
  --data "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<c:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">
  <d:prop>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name=\"VCALENDAR\">
      <c:comp-filter name=\"VEVENT\">
        <c:time-range start=\"${START}\" end=\"${END}\"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>" \
  "${NEXTCLOUD_SERVER_URL}/remote.php/dav/calendars/${NEXTCLOUD_USERNAME}/${NEXTCLOUD_CALENDAR_PATH}/"
