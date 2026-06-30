#!/bin/bash

###############################################################################
# transfer_to_remote.sh
#
# Transfers large files and directories not tracked by git to a remote location.
#
# Usage:
#   ./transfer_to_remote.sh [file_or_dir ...] [-d remote_dir] [-h]
#
# By default, transfers to:
#   squaade@midway2.rcc.uchicago.edu:/project/rglennerster/pandemic_model
#
# If no files or directories are provided explicitly, the following are transferred:
#   data/clean/arrival_distributions
#   data/clean/duration_distributions
##
# Options:
#   -d remote_dir     Override the default remote directory.
#   -h                Show this help message and exit.
#
###############################################################################

set -e

DEFAULT_REMOTE_USER="squaade"
DEFAULT_REMOTE_HOST="midway2.rcc.uchicago.edu"
DEFAULT_REMOTE_DIR="/project/rglennerster/pandemic_model"

DEFAULT_PATHS=(
    "data/clean/arrival_distributions"
    "data/clean/duration_distributions"
)

usage() {
    echo "Usage: $0 [file_or_dir ...] [-d remote_dir] [-h]"
    echo
    echo "Transfer large files and folders to (by default):"
    echo "  ${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}:${DEFAULT_REMOTE_DIR}"
    echo
    echo "Paths are transferred with their relative directory structure preserved."
    echo
    echo "If no paths are given, the following will be transferred by default:"
    for path in "${DEFAULT_PATHS[@]}"; do
        echo "  $path"
    done
    echo
    echo "Options:"
    echo "  -d remote_dir     Override default remote directory."
    echo "  -h                Show this help message and exit."
    echo
    echo "  TAR_CHECKPOINT=N  Records between GNU tar checkpoint dots (default: 8192)"
    exit 1
}

REMOTE_DIR="${DEFAULT_REMOTE_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Parse options
while getopts ":d:h" opt; do
  case ${opt} in
    d )
      REMOTE_DIR="$OPTARG"
      ;;
    h )
      usage
      ;;
    \? )
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# If no files/dirs are given, use default list
if [ $# -lt 1 ]; then
    SRC_LIST=("${DEFAULT_PATHS[@]}")
else
    SRC_LIST=("$@")
fi

# Validate that all paths exist
FINAL_SRC_LIST=()
for SRC in "${SRC_LIST[@]}"; do
    if [ ! -e "$SRC" ]; then
        echo "Warning: '$SRC' does not exist. Skipping."
    else
        FINAL_SRC_LIST+=("$SRC")
    fi
done

if [ ${#FINAL_SRC_LIST[@]} -eq 0 ]; then
    echo "No valid files or directories to transfer."
    exit 2
fi

echo "Transferring to ${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}:${REMOTE_DIR}/"
for SRC in "${FINAL_SRC_LIST[@]}"; do
    echo "  $SRC"
done

REMOTE_DIR_Q=$(printf '%q' "${REMOTE_DIR}")
TAR_CHECKPOINT="${TAR_CHECKPOINT:-8192}"

tar --checkpoint="${TAR_CHECKPOINT}" --checkpoint-action=dot -czf - "${FINAL_SRC_LIST[@]}" \
  | ssh "${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}" "cd ${REMOTE_DIR_Q} && tar xzf -"

echo "Transfer complete."
