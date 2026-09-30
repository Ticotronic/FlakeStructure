#!/usr/bin/env bash
# Listet alle CalDAV-Kalendersammlungen im Calendar-Home des Nutzers auf
# (PROPFIND, Depth 1) inklusive ihrer unterstuetzten Komponenten
# (VEVENT/VTODO/...) und Anzeigenamen. QML filtert daraus die Sammlungen,
# die VTODO unterstuetzen (= Task-Listen), und ruft dann
# nextcloud-tasks-fetch mit deren hrefs auf.
# Erwartet folgende Umgebungsvariablen (werden vom Nix-Wrapper gesetzt):
#   NEXTCLOUD_SERVER_URL      z.B. https://cloud.example.com
#   NEXTCLOUD_USERNAME        Nextcloud-Benutzername
#   NEXTCLOUD_PASSWORD_FILE   Pfad zur sops-entschluesselten App-Passwort-Datei
set -euo pipefail

curl -s -X PROPFIND \
  -H "Depth: 1" \
  -H "Content-Type: application/xml; charset=utf-8" \
  -u "${NEXTCLOUD_USERNAME}:$(cat "${NEXTCLOUD_PASSWORD_FILE}")" \
  --data "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">
  <d:prop>
    <d:resourcetype/>
    <d:displayname/>
    <c:supported-calendar-component-set/>
  </d:prop>
</d:propfind>" \
  "${NEXTCLOUD_SERVER_URL}/remote.php/dav/calendars/${NEXTCLOUD_USERNAME}/"
