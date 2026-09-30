#!/usr/bin/env bash
# Ruft alle VTODOs aus einer oder mehreren CalDAV-Kalendersammlungen ab.
# Nimmt die absoluten Server-Pfade (hrefs, wie von der PROPFIND-Discovery
# geliefert) als Argumente entgegen, z.B.:
#   nextcloud-tasks-fetch /remote.php/dav/calendars/roljon/personal/
# Fuer jeden href wird eine Marker-Zeile "### HREF <href>" ausgegeben,
# gefolgt vom rohen REPORT-Ergebnis (multistatus XML) fuer genau diese
# Sammlung. QML trennt die Ausgabe an diesen Markern, damit jede Aufgabe
# ihrer Ursprungsliste (href) zugeordnet werden kann. Reine curl-Huelle -
# jegliches XML-Parsing passiert in QML (NextcloudTasksDAV.qml).
# Erwartet folgende Umgebungsvariablen (werden vom Nix-Wrapper gesetzt):
#   NEXTCLOUD_SERVER_URL      z.B. https://cloud.example.com
#   NEXTCLOUD_USERNAME        Nextcloud-Benutzername
#   NEXTCLOUD_PASSWORD_FILE   Pfad zur sops-entschluesselten App-Passwort-Datei
set -euo pipefail

AUTH="${NEXTCLOUD_USERNAME}:$(cat "${NEXTCLOUD_PASSWORD_FILE}")"

REPORT_BODY='<?xml version="1.0" encoding="utf-8" ?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>'

for HREF in "$@"; do
  echo "### HREF ${HREF}"
  curl -s -X REPORT \
    -H "Depth: 1" \
    -H "Content-Type: application/xml; charset=utf-8" \
    -u "${AUTH}" \
    --data "${REPORT_BODY}" \
    "${NEXTCLOUD_SERVER_URL}${HREF}"
  echo ""
done
