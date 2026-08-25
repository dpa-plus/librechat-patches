# 004 — Video-/Audio-Uploads für Werkzeug-Sidecars

**Applied:** yes — built into the image, see `Dockerfile`
**Type:** B (off-by-default switch, see the rule in the repository README)
**Base:** v0.8.7
**Upstream status:** not offered yet

LibreChat bietet Rohvideo und -audio standardmäßig nur Endpunkten an, die diese
Medien selbst verarbeiten. Ein Custom-Endpunkt wie Cortecs bekommt deshalb bei
MP4 keinen nutzbaren Provider-Upload, obwohl ein MCP-Sidecar die lokal
gespeicherte Datei lesen könnte.

Dieser Patch ergänzt den off-by-default-Schalter
`uploadMethods.providerVideoAudio`. Nur wenn er am Endpoint oder ModelSpec auf
`true` steht, lässt LibreChat Video und Audio über den direkten Uploadpfad zu.
Die Datei bleibt dabei im lokalen LibreChat-Speicher; der Custom-Chat-Client
erhält weiterhin nur die normalen Dateimetadaten. Das Sidecar löst die Datei
separat und nutzergebunden auf.

ModelSpec-Konfiguration gewinnt gegenüber der Endpoint-Konfiguration. Ein
explizites `provider: false` bleibt eine harte Sperre. Ohne den neuen Schlüssel
ist das Verhalten bitgenau zu Patch 002 bzw. Upstream unverändert.

Der Patch wird nach 002 und 003 angewendet und erweitert zwei mit Patch 002
eingeführte Dateien. Seine Tests decken Default, Opt-in, Override,
`provider: false`, Video, Audio und Auto-Routing ab.

Beispiel:

```yaml
modelSpecs:
  list:
    - name: video-analyse
      uploadMethods:
        provider: true
        providerVideoAudio: true
        autoRoute: true

fileConfig:
  endpoints:
    Cortecs:
      supportedMimeTypes: ['video/.*']
      uploadMethods:
        provider: true
        providerVideoAudio: true
        autoRoute: true
```
