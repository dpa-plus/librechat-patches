#!/usr/bin/env bash
# Stellt einen LibreChat-Arbeitsbaum mit angewendeten Patches her.
#
# Der Sinn: Ein solcher Baum ist ein Wegwerfartikel. Was zaehlt, sind die
# Patch-Dateien in diesem Repository. Geht der Baum verloren, kostet das eine
# Minute statt einer Woche.
#
#   tools/worktree.sh                  # Basis aus dem Dockerfile, Ziel .worktree/
#   tools/worktree.sh v0.8.8-rc1       # andere Version
#   tools/worktree.sh v0.8.7 /pfad     # anderes Ziel
#   NPM_INSTALL=1 tools/worktree.sh    # zusaetzlich Abhaengigkeiten holen
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

TAG="${1:-$(grep -m1 '^ARG LIBRECHAT_VERSION=' Dockerfile | cut -d= -f2)}"
DEST="${2:-$REPO_ROOT/.worktree}"

[ -e "$DEST" ] && { echo "Ziel existiert bereits: $DEST"; echo "Erst entfernen oder anderes Ziel angeben."; exit 1; }

echo "LibreChat $TAG -> $DEST"
git clone -q --depth 1 --branch "$TAG" https://github.com/danny-avila/LibreChat.git "$DEST" 2>&1 | grep -v "detached HEAD|advice.detachedHead|^$" || true
  git -C "$DEST" config advice.detachedHead false

# Patches anwenden, die als Diff vorliegen und deren Basis zu diesem Tag passt.
angewendet=0
for dir in "$REPO_ROOT"/patches/*/; do
  name=$(basename "$dir")
  patchfile=$(ls "$dir"/*.patch 2>/dev/null | head -1) || true
  [ -n "${patchfile:-}" ] || continue
  base=$(grep -m1 '^\*\*Base:\*\*' "$dir/README.md" | sed 's/.*Base:\*\* *//' | cut -d' ' -f1)
  if [ "$base" != "$TAG" ]; then
    echo "  $name uebersprungen (Basis $base, nicht $TAG)"
    continue
  fi
  if (cd "$DEST" && git apply --check "$patchfile" 2>/dev/null); then
    (cd "$DEST" && git apply "$patchfile")
    echo "  $name angewendet"
    angewendet=$((angewendet+1))
  else
    echo "  $name PASST NICHT auf $TAG:"
    (cd "$DEST" && git apply --check "$patchfile" 2>&1 | sed 's/^/      /' | head -10) || true
    exit 1
  fi
done

# Dateien, die als Ganzes vorliegen (Patch 001), hineinkopieren — aber nur,
# wenn die Datei am angeforderten Tag noch dem Stand entspricht, gegen den der
# Patch gebaut wurde (upstream.sha256). Sonst wuerde ein stillschweigendes
# Kopieren Upstream-Fixes ueberschreiben, waehrend Diff-Patches oben laut
# scheitern. Gleiche Haerte fuer beide Formen.
for dir in "$REPO_ROOT"/patches/*/; do
  name=$(basename "$dir")
  ls "$dir"/*.patch >/dev/null 2>&1 && continue
  while read -r erwartet rel; do
    [ -n "$rel" ] || continue
    quelle="$dir/$(basename "$rel")"
    [ -f "$quelle" ] || continue
    ist=$(shasum -a 256 "$DEST/$rel" 2>/dev/null | cut -d' ' -f1 || true)
    if [ "$ist" != "$erwartet" ]; then
      echo "  $name PASST NICHT auf $TAG:"
      echo "      $rel hat sich upstream geaendert (sha256 weicht von upstream.sha256 ab)."
      echo "      Ganzdatei-Patch gegen den neuen Stand neu aufsetzen, dann upstream.sha256 aktualisieren."
      exit 1
    fi
    cp "$quelle" "$DEST/$rel"
    echo "  $name kopiert -> $rel"
    angewendet=$((angewendet+1))
  done < "$dir/upstream.sha256"
done

echo "$angewendet Patch(es) im Baum."

if [ "${NPM_INSTALL:-0}" = "1" ]; then
  echo "npm ci laeuft, das dauert."
  (cd "$DEST" && npm ci)
fi

echo
echo "Fertig. Aenderungen ansehen:  git -C $DEST diff --stat"
echo "Aufraeumen:                   rm -rf $DEST"
