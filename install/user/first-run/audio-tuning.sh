#!/bin/bash

# Apply speaker tuning for this laptop. Runs at first-run rather than at
# finalize-user time because finalize-user can also run before a session
# audio server exists: the sink the tuning has to target does not exist yet,
# so nothing could be written and nothing would retry. By first-run the
# session is up and the sink is present.
#
# A no-op on machines no tuning matches.

set -euo pipefail

fedory-audio-tuning on
