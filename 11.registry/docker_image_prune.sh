#!/bin/bash
#
# Remove old images from docker images
# by sb 2018
# v 0.2
#

set -o nounset
set -o errtrace
set -o pipefail

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")" 
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly -a BIN_REQUIRED=( docker )

typeset KEEP_IMAGES=5
typeset REMOVE_STOPPED_CONTAINERS=0
typeset REMOVE_UNTAGGED_IMAGE=0
typeset DRY_RUN=0

main() {
  if (( REMOVE_STOPPED_CONTAINERS )); then
    # remove stopped containers
    if (( ! DRY_RUN ));then
      docker ps -aq --no-trunc -f status=exited | xargs docker rm
    fi
  fi

  if (( REMOVE_UNTAGGED_IMAGE )); then
    # remove untagged images
    if (( ! DRY_RUN)); then
      (docker images -q --filter dangling=true | xargs docker rmi ) 2>/dev/null
    fi
  fi

  local TAIL=$((KEEP_IMAGES + 2))
  docker images --format "{{.Repository}}" | sort -u | while read -r repo; do
    CURR=0
    docker images "$repo" --format "{{.ID}}" | while read -r ID; do
      CURR=$((CURR + 1))
      if [ "$CURR" -gt "$TAIL" ]; then
        echo "$repo $ID remove " 
        if (( ! DRY_RUN ));then
          docker rmi -f "$ID" 
        fi
      fi
    done
  done
}

usage() {
    echo -e "\\tUsage: $bn [OPTIONS] <parameter>\\n
    Options:

    -c, --keep-count n                          keep at least n images (default: 5)
    -u, --remove-untagged                       remove untagged images
    -s, --remive-stopped                        remove stopped containers
    -n, --dry-run                               don't make any changes
    -h, --help                                  print out help
" 
}

# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o c:usnh --longoptions keep-count:,remove-untagged,remove-stopped,dry-run,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP" 
unset TEMP

while true; do
    case $1 in
        -c|--keep-count)        KEEP_IMAGES=$2 ;      shift 2 ;;
        -u|--remove-untagged)   REMOVE_UNTAGGED_IMAGE=1; shift ;;
        -s|--remive-stopped)    REMOVE_STOPPED_CONTAINERS=1; shift ;;
        -n|--dry-run)           DRY_RUN=1 ;     shift   ;;
        -h|--help)              usage ;         exit 0  ;;
        --)                     shift ;         break   ;;
        *)                      usage ;         exit 1
    esac
done

main