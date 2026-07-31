# Detect MacBook models that need SPI keyboard modules
#
# Fedora-native rewrite: mkinitcpio.conf.d MODULES=(...) -> dracut.conf.d
# force_drivers+= (same pattern as fix-surface-keyboard.sh).
product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
if [[ $product_name =~ MacBook[89],1|MacBook1[02],1|MacBookPro13,[123]|MacBookPro14,[123] ]]; then
  echo "Detected MacBook with SPI keyboard"

  fedory-pkg-add macbook12-spi-driver-dkms
  sudo mkdir -p /etc/dracut.conf.d
  if [[ $product_name == "MacBook8,1" ]]; then
    echo 'force_drivers+=" applespi spi_pxa2xx_platform spi_pxa2xx_pci "' | \
      sudo tee /etc/dracut.conf.d/macbook-spi-modules.conf >/dev/null
  else
    echo 'force_drivers+=" applespi intel_lpss_pci spi_pxa2xx_platform "' | \
      sudo tee /etc/dracut.conf.d/macbook-spi-modules.conf >/dev/null
  fi
  sudo dracut -f
fi
