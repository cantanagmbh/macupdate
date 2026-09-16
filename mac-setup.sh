#!/bin/bash
#
# Basis-Setup für neue MacBooks
# ------------------------------
# Auf dem frischen Mac ausführen (vor Übergabe an den Mitarbeiter):
#
#   curl -fsSL https://raw.githubusercontent.com/cantanagmbh/macupdate/main/mac-setup.sh -o ~/mac-setup.sh && bash ~/mac-setup.sh
#
# Voraussetzung: Das Benutzerkonto muss Administrator sein.
#   Systemeinstellungen -> Benutzer:innen & Gruppen -> Konto -> ⓘ ->
#   "Darf diesen Computer verwalten" aktivieren (danach ab-/anmelden).
#
# Das Skript fragt einmal nach dem Anmeldepasswort. Ansonsten keine Logins.
#
# Installiert: sipgate, Microsoft Teams, Word, Excel, PowerPoint,
#              Google Chrome, Dropbox, Notion, Adobe Creative Cloud
#

set -euo pipefail

info()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m  !\033[0m %s\n" "$1"; }
fail()  { printf "\n\033[1;31m  ✗ %s\033[0m\n\n" "$1"; exit 1; }

# ---------------------------------------------------------------------------
# 0. Administratorrechte prüfen und Passwort einmal abfragen
# ---------------------------------------------------------------------------
# Homebrew braucht Adminrechte. Wir fragen das Passwort hier bewusst selbst ab
# und halten die Berechtigung wach, damit die Installation nicht mittendrin
# nach dem Passwort fragt oder abbricht.

if ! id -Gn | grep -qw admin; then
  fail "Der Benutzer '$(whoami)' ist kein Administrator.
    Bitte in den Systemeinstellungen unter 'Benutzer:innen & Gruppen'
    die Option 'Darf diesen Computer verwalten' aktivieren,
    einmal ab- und wieder anmelden und das Skript erneut starten."
fi

info "Bitte einmal das Anmeldepasswort eingeben"
echo "  (beim Tippen erscheinen keine Zeichen - das ist normal)"
sudo -v || fail "Passwort nicht akzeptiert - Setup abgebrochen."

# sudo-Berechtigung im Hintergrund wach halten, solange das Skript läuft
( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

ok "Administratorrechte bestätigt"

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools (Voraussetzung für Homebrew)
# ---------------------------------------------------------------------------
if xcode-select -p >/dev/null 2>&1; then
  ok "Command Line Tools bereits installiert"
else
  info "Installiere Command Line Tools"
  warn "Es öffnet sich ein Dialog - bitte auf 'Installieren' klicken."
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
  done
  ok "Command Line Tools installiert"
fi

# ---------------------------------------------------------------------------
# 2. Homebrew
# ---------------------------------------------------------------------------
if [[ "$(uname -m)" == "arm64" ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"     # Apple Silicon
else
  BREW_BIN="/usr/local/bin/brew"        # Intel
fi

if [[ -x "$BREW_BIN" ]]; then
  ok "Homebrew bereits installiert"
else
  info "Installiere Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installiert"
fi

[[ -x "$BREW_BIN" ]] || fail "Homebrew wurde nicht gefunden - Installation fehlgeschlagen."

eval "$("$BREW_BIN" shellenv)"

# brew dauerhaft im PATH aller Shells verankern
for PROFILE in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  LINE="eval \"\$($BREW_BIN shellenv)\""
  touch "$PROFILE"
  grep -qF "$LINE" "$PROFILE" || echo "$LINE" >> "$PROFILE"
done
ok "Homebrew im PATH verankert"

# ---------------------------------------------------------------------------
# 3. Programme
# ---------------------------------------------------------------------------
# Namen nachschlagen:  brew search --cask <suchbegriff>
#                      oder https://formulae.brew.sh/cask/

info "Installiere Programme (dauert ca. 10-20 Minuten, Adobe CC ist groß)"

# Downloads nacheinander statt parallel. Homebrew lädt seit Version 5.0
# standardmäßig mehrere Pakete gleichzeitig - Microsofts Download-Server
# bricht dabei regelmäßig Verbindungen ab ("Download failed").
export HOMEBREW_DOWNLOAD_CONCURRENCY=1

install_apps() {
brew bundle --file=- <<'BREWFILE'
# --- Telefonie -------------------------------------------------------------
cask "sipgate"                     # aktuelle sipgate-App (Nachfolger des alten Softphone)

# --- Kommunikation ---------------------------------------------------------
cask "microsoft-teams"

# --- Office ----------------------------------------------------------------
cask "microsoft-word"
cask "microsoft-excel"
cask "microsoft-powerpoint"

# --- Browser ---------------------------------------------------------------
cask "google-chrome"

# --- Cloud / Organisation --------------------------------------------------
cask "dropbox"
cask "notion"

# --- Grafik ----------------------------------------------------------------
# Achtung: installiert NUR die Creative-Cloud-App, nicht Photoshop/Illustrator
# selbst. Siehe Hinweis am Ende dieses Skripts.
cask "adobe-creative-cloud"

# --- Optional (bei Bedarf entkommentieren) ---------------------------------
# cask "rectangle"                 # Fenster per Tastenkürzel anordnen
# cask "the-unarchiver"            # entpackt so ziemlich alles
# cask "adobe-acrobat-reader"
BREWFILE
}

# Erster Versuch; bei fehlgeschlagenen Downloads automatisch ein zweiter.
if install_apps; then
  ok "Alle Programme installiert"
else
  warn "Einige Downloads sind fehlgeschlagen - zweiter Versuch in 10 Sekunden"
  sleep 10
  install_apps || warn "Es konnten nicht alle Programme installiert werden."
fi

# ---------------------------------------------------------------------------
# 4. Optionale System-Einstellungen
# ---------------------------------------------------------------------------
# Zum Aktivieren die jeweilige Zeile entkommentieren.

# defaults write com.apple.finder AppleShowAllExtensions -bool true   # Dateiendungen zeigen
# defaults write com.apple.dock autohide -bool true                   # Dock ausblenden
# defaults write NSGlobalDomain AppleICUForce24HourTime -bool true    # 24-Stunden-Zeit
# killall Finder Dock 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Abschlussprüfung
# ---------------------------------------------------------------------------
info "Prüfe, was im Programme-Ordner gelandet ist"

MISSING=0
check_app() {
  if [[ -e "$1" ]]; then
    ok "$2"
  else
    warn "$2 fehlt"
    MISSING=$((MISSING + 1))
  fi
}

check_app "/Applications/sipgate.app"                "sipgate"
check_app "/Applications/Microsoft Teams.app"        "Microsoft Teams"
check_app "/Applications/Microsoft Word.app"         "Microsoft Word"
check_app "/Applications/Microsoft Excel.app"        "Microsoft Excel"
check_app "/Applications/Microsoft PowerPoint.app"   "Microsoft PowerPoint"
check_app "/Applications/Google Chrome.app"          "Google Chrome"
check_app "/Applications/Dropbox.app"                "Dropbox"
check_app "/Applications/Notion.app"                 "Notion"
check_app "/Applications/Adobe Creative Cloud"       "Adobe Creative Cloud"

if [[ "$MISSING" -gt 0 ]]; then
  echo
  warn "$MISSING Programm(e) fehlen. Einzeln nachinstallieren, z. B.:"
  warn "    brew install --cask microsoft-word"
fi

# ---------------------------------------------------------------------------
# Fertig
# ---------------------------------------------------------------------------
info "Setup abgeschlossen"
cat <<'EOF'

  Noch von Hand zu erledigen:

  - Photoshop / Illustrator: Creative Cloud öffnen, mit dem Adobe-Konto
    anmelden und die beiden Apps dort installieren.

  - Word / Excel / PowerPoint / Teams: beim ersten Start einmal mit dem
    Microsoft-365-Konto anmelden, sonst laufen sie nur im Lesemodus.

  - Dropbox, Notion und sipgate: Anmeldung durch den Mitarbeiter.

  - Falls das Konto nur für die Installation Adminrechte bekommen hat:
    jetzt wieder auf Standardbenutzer zurückstellen.

  Spätere Updates aller Programme auf einmal (neues Terminal-Fenster):

      brew update && brew upgrade && brew upgrade --cask

EOF
