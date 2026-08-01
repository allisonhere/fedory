# Install portable tools that Fedora does not package. These wrappers use
# mise's registry/backends, so the actual tool is installed per-user on first
# launch and kept current through the same mechanism as Fedory's other CLI
# tools.

fedory-mise-install lazygit
fedory-mise-install lazydocker
fedory-mise-install starship
fedory-mise-install dua
fedory-mise-install tree-sitter
fedory-mise-install usage

# mise's pipx backend uses uv when available. Providing the uv wrapper first
# keeps these Python applications isolated from Fedora's system Python.
fedory-mise-install uv
fedory-mise-install pipx:terminaltexteffects tte
fedory-mise-install pipx:tzupdate tzupdate
