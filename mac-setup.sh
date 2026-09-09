#!/bin/bash
#
# Basis-Setup für neue MacBooks
# ------------------------------
# Auf dem frischen Mac ausführen (vor Übergabe an den Mitarbeiter):
#
#   1. Terminal öffnen (Cmd+Leertaste -> "Terminal")
#   2. bash ~/Downloads/mac-setup.sh
#
# Das Skript fragt einmal nach dem Admin-Passwort des Macs (für Homebrew).
# Ansonsten sind keine Logins nötig.
#
# Installiert: sipgate, Microsoft Teams, Word, Excel, PowerPoint,
#              Google Chrome, Dropbox, Adobe Creative Cloud
#

set -euo pipefail

info()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m  !\033[0m %s\n" "$1"; }

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools (Voraussetzung für Homebrew)
# ---------------------------------------------------------------------------
if xcode-select -p >/dev/null 2>&1; then
  ok "Command Line Tools bereits installiert"
else
  info "Installiere Command Line Tools"
  warn "Es öffnet sich ein Dialog – bitte auf 'Installieren' klicken."
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
  info "Installiere Homebrew (Admin-Passwort wird abgefragt)"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installiert"
fi

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

brew bundle --no-lock --file=- <<'BREWFILE'
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

# --- Cloud -----------------------------------------------------------------
cask "dropbox"

# --- Grafik ----------------------------------------------------------------
# Achtung: installiert NUR die Creative-Cloud-App, nicht Photoshop/Illustrator
# selbst. Siehe Hinweis am Ende dieses Skripts.
cask "adobe-creative-cloud"

# --- Optional (bei Bedarf entkommentieren) ---------------------------------
# cask "rectangle"                 # Fenster per Tastenkürzel anordnen
# cask "the-unarchiver"            # entpackt so ziemlich alles
# cask "adobe-acrobat-reader"
BREWFILE

ok "Programme installiert"

# ---------------------------------------------------------------------------
# 4. Optionale System-Einstellungen
# ---------------------------------------------------------------------------
# Zum Aktivieren die jeweilige Zeile entkommentieren.

# defaults write com.apple.finder AppleShowAllExtensions -bool true   # Dateiendungen zeigen
# defaults write com.apple.dock autohide -bool true                   # Dock ausblenden
# defaults write NSGlobalDomain AppleICUForce24HourTime -bool true    # 24-Stunden-Zeit
# killall Finder Dock 2>/dev/null || true

# ---------------------------------------------------------------------------
# Fertig
# ---------------------------------------------------------------------------
info "Setup abgeschlossen"
cat <<'EOF'

  Noch von Hand zu erledigen:

  - Photoshop / Illustrator: Creative Cloud öffnen, mit dem Adobe-Konto
    anmelden und die beiden Apps dort installieren.
    (Alternative ohne Login am Gerät: fertiges Installationspaket in der
     Adobe Admin Console erzeugen – siehe Notiz im Chat.)

  - Word / Excel / PowerPoint / Teams: beim ersten Start einmal mit dem
    Microsoft-365-Konto anmelden, sonst laufen sie nur im Lesemodus.

  - Dropbox und sipgate: Anmeldung durch den Mitarbeiter.

  Spätere Updates aller Programme auf einmal:

      brew update && brew upgrade && brew upgrade --cask

EOF
