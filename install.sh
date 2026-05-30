#!/bin/bash
# =============================================================================
# Raspberry Pi 5 Kiosk Setup Script
#
# Usage:
#   sudo bash kiosk-setup.sh <url>
#
# curl usage:
#   curl -fsSL https://your-host/kiosk-setup.sh | sudo bash -s -- <url>
# =============================================================================

set -e

KIOSK_USER="kiosk"
KIOSK_URL="${1:-https://tmo.chapelthrillescapes.com/room2}"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

echo "==> Kiosk URL: $KIOSK_URL"

# --- User ---------------------------------------------------------------------

echo "==> Creating kiosk user: $KIOSK_USER"
if id "$KIOSK_USER" &>/dev/null; then
  echo "    User already exists, skipping creation."
else
  useradd -m -s /bin/bash "$KIOSK_USER"
  passwd -l "$KIOSK_USER"
fi

usermod -aG video,audio,input,render "$KIOSK_USER"

# --- Packages -----------------------------------------------------------------

echo "==> Installing required packages"
apt-get update -qq
apt-get install -y --no-install-recommends chromium-browser

# --- Autologin ----------------------------------------------------------------

echo "==> Configuring autologin via raspi-config"
raspi-config nonint do_boot_behaviour B4
sed -i "s/^autologin-user=.*/autologin-user=$KIOSK_USER/" /etc/lightdm/lightdm.conf

# --- Autostart ----------------------------------------------------------------

echo "==> Writing autostart desktop files"
AUTOSTART_DIR="/home/$KIOSK_USER/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/screensaver-off.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Disable Screensaver
Exec=xset s off -dpms
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP

cat > "$AUTOSTART_DIR/chromium-kiosk.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Chromium Kiosk
Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-restore-session-state --disable-translate --disable-features=TranslateUI --check-for-update-interval=31536000 --autoplay-policy=no-user-gesture-required $KIOSK_URL
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP

# --- Chromium preferences -----------------------------------------------------

echo "==> Writing Chromium preferences"
CHROMIUM_PREFS_DIR="/home/$KIOSK_USER/.config/chromium/Default"
mkdir -p "$CHROMIUM_PREFS_DIR"

cat > "$CHROMIUM_PREFS_DIR/Preferences" <<PREFS
{
  "profile": {
    "default_content_setting_values": {
      "media_stream": 1
    },
    "content_settings": {
      "exceptions": {
        "autoplay": {
          "*,*": {
            "setting": 1
          }
        }
      }
    }
  }
}
PREFS

# --- Permissions --------------------------------------------------------------

chown -R "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER/.config"

echo ""
echo "============================================================"
echo " Done! Reboot to start the kiosk."
echo " User:  $KIOSK_USER"
echo " URL:   $KIOSK_URL"
echo " Reboot with: sudo reboot"
echo "============================================================"
