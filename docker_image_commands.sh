#!/usr/bin/env bash
# ---------------------------------------------------------------------------------
# Docker utility tool to get commands used to build a docker image from remote
# secure registry. The image is based on the official NAME[:TAG|@DIGEST] convention.
# Usage: ./docker_image_commands.sh image1 image2
# ---------------------------------------------------------------------------------

set -o errexit
set -o pipefail
set -o nounset

if [[ $# -eq 0 ]]; then
  echo "You should pass at least one Docker image to get details from!"
  exit 1
fi

for TOOL in curl jq; do
  if ! [ -x "$(command -v ${TOOL})" ]; then
    echo "Error: ${TOOL} is not installed." >&2
    exit 1
  fi
done

for IMAGE in "$@"; do
  # TL;DR: The hostname must contain a . dns separator or a : port separator before the first /, otherwise the code assumes you want the default registry.
  IMAGE_URL=$([[ ${IMAGE%%/*} =~ \.|: ]] && echo "${IMAGE%%/*}" || echo "")
  IMAGE_NAME=`echo ${IMAGE#${IMAGE_URL}/} | awk -F '[:@]' '{print $1}'`
  IMAGE_TAG=`echo ${IMAGE#${IMAGE_URL}/} | awk -F '[:@]' '{print $2}'`

  if [[ -z ${IMAGE_URL} ]]; then
    # Fallback to default docker registry
    IMAGE_URL="registry-1.docker.io"
    TOKEN=$(curl -s "https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io" | jq -r .token)
  else
    TOKEN=$(curl -sL "https://${IMAGE_URL}/v2/token" | jq -r .token)
  fi

  CONFIG_DIGEST=$(curl -sL -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer ${TOKEN}" https://${IMAGE_URL}/v2/${IMAGE_NAME}/manifests/${IMAGE_TAG:=latest} | jq -r .config.digest)
  echo -e "\x1b[34;3mDocker image '${IMAGE}' is created with the following commands:\x1b[0m"
  echo "$(curl -sL -H"Authorization: Bearer ${TOKEN}" "https://${IMAGE_URL}/v2/${IMAGE_NAME}/blobs/${CONFIG_DIGEST}" | jq -r '.history | .[].created_by')" | awk '{ print "\t" $0 }'
done
