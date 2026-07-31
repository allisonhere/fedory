# Setup default work directory (and tries)
mkdir -p "$HOME/Work"
mkdir -p "$HOME/Work/tries"

cat >"$HOME/Work/.mise.toml" <<'EOF'
[env]
_.path = "{{ cwd }}/bin"
EOF

mise trust ~/Work/.mise.toml

# Upstream's iso-chroot branch installs a bundled Node.js tarball from
# /opt/packages here, because the ISO's target chroot has no network access
# yet. bootstrap.sh always runs online against a live system (see
# docs/scope.md), so Fedory only ever needs the plain online path.
mise use -g node@latest
