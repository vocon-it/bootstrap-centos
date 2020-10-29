# Exit on error:
set -e

git config --global credential.helper store && echo success || false

