#!/bin/bash

# The original SVG icon sources were removed during the nts rebrand.
# All app icons are now derived from assets/icon/nts_master.png (1024x1024),
# so the old SVG pipeline would regenerate the wrong (pre-rebrand) icons.
echo "generate_icons.sh is disabled: nts icons are derived from assets/icon/nts_master.png."
echo "Regenerate the platform icons from that image instead."
exit 1
