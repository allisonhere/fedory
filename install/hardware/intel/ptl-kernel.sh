# Upstream installs a separate linux-ptl kernel package (with Panther Lake
# audio driver patches not yet in mainline) for Dell XPS Panther Lake
# systems, forcibly removing the stock kernel and adding Limine boot-menu
# ordering so linux-ptl is the default entry.
#
# Fedora-native note: this doesn't translate. Fedora ships one mainline
# `kernel` package that tracks upstream on its own release cadence rather
# than Arch's model of parallel-installable specialized kernel packages
# (linux, linux-zen, linux-ptl, ...) -- see the linux-ptl / linux-ptl-headers
# rows in packaging/package-map.tsv (both marked dropped for this reason).
# There's no separate PTL-patched kernel package to swap to, and swapping
# kernels or removing the stock one isn't something to improvise here.
#
# If Panther Lake audio needs patches genuinely absent from Fedora's kernel,
# that's tracked upstream in the mainline kernel / Fedora's own kernel
# packaging, not solved by this installer.

if fedory-hw-match "XPS" && fedory-hw-intel-ptl; then
  echo "Detected Dell XPS Panther Lake. Fedora has no separate PTL-patched"
  echo "kernel package to install here (see this script's header comment) --"
  echo "using the stock Fedora kernel."
fi
