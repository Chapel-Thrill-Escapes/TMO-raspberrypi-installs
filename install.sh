#!/bin/bash
# =============================================================================
# Raspberry Pi 5 Kiosk Setup Script
#
# Usage:
#   sudo bash kiosk-setup.sh
#   KIOSK_URL="https://example.com" sudo -E bash kiosk-setup.sh
#
# curl usage:
#   curl -fsSL https://your-host/kiosk-setup.sh | KIOSK_URL="https://example.com" sudo -E bash
# =============================================================================

set -e

# --- Configuration -----------------------------------------------------------
KIOSK_USER="kiosk"
KIOSK_URL="${KIOSK_URL:-https://tmo.chapelthrillescapes.com/room2}"
# -----------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

echo "==> Kiosk URL: $KIOSK_URL"

echo "==> Creating kiosk user: $KIOSK_USER"
if id "$KIOSK_USER" &>/dev/null; then
  echo "    User already exists, skipping creation."
else
  useradd -m -s /bin/bash "$KIOSK_USER"
  passwd -l "$KIOSK_USER"  # Lock password login (autologin only)
fi

usermod -aG video,audio,input,render "$KIOSK_USER"

echo "==> Installing required packages"
apt-get update -qq
apt-get install -y --no-install-recommends \
  chromium-browser

echo "==> Configuring autologin via raspi-config"
raspi-config nonint do_boot_behaviour B4

# raspi-config sets autologin for the 'pi' user by default — point it to ours
sed -i "s/^autologin-user=.*/autologin-user=$KIOSK_USER/" /etc/lightdm/lightdm.conf

echo "==> Setting up Openbox autostart for $KIOSK_USER"
OPENBOX_DIR="/home/$KIOSK_USER/.config/openbox"
mkdir -p "$OPENBOX_DIR"

cat > "$OPENBOX_DIR/autostart" <<AUTOSTART
# Disable screen blanking and power management
xset s off &
xset s noblank &
xset -dpms &

# Launch Chromium in kiosk mode
chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --disable-translate \
  --disable-features=TranslateUI \
  --check-for-update-interval=31536000 \
  --autoplay-policy=no-user-gesture-required \
  "$KIOSK_URL" &
AUTOSTART

chown -R "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER/.config"

echo ""
echo "============================================================"
echo " Done! Reboot to start the kiosk."
echo " User:  $KIOSK_USER"
echo " URL:   $KIOSK_URL"
echo " Reboot with: sudo reboot"
echo "============================================================"
