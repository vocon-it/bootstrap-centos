#!/usr/bin/env bash
#
# solves issue CAAS-154
#   url:   https://vocon-it.atlassian.net/browse/CAAS-154
#   title: IntelliJDesktop ng serve: Error: ENOSPC: System limit for number of file watchers reached
#

# Exit on error:
set -e

sudo cat /etc/sysctl.conf | grep -q 'max_user_watches' && echo "max_user_watches already increased. Nothing to do." && exit 0

cat << EOF | sudo tee -a /etc/sysctl.conf
fs.inotify.max_user_watches=524288
EOF

sudo sysctl -p

