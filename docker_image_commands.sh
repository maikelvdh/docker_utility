#!/usr/bin/env bash
# ---------------------------------------------------------------------------------
# Docker utility tool to get commands used to build a docker image from remote
# secure registry. The image is based on the official NAME[:TAG|@DIGEST] convention.
# Usage: ./docker_image_commands.sh image1 image2
# ---------------------------------------------------------------------------------

set -o errexit
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
  IMAGE_URL=$(echo ${IMAGE} | awk '/[.:]+.*\//' | awk -F '/' '{ print $1 }') # TL;DR: The hostname must contain a '.'' dns separator or a ':'' port separator before the first /
  IMAGE_NAME=`echo ${IMAGE#${IMAGE_URL}/} | awk -F '[:@]' '{print $1}'`
  IMAGE_TAG=`echo ${IMAGE#${IMAGE_URL}/} | awk -F '[:@]' '{print $2}'`

  # Fallback to default docker registry
  if [[ -z ${IMAGE_URL} ]]; then
    IMAGE_URL="registry-1.docker.io"
    [[ -z $(echo ${IMAGE_NAME} | awk '/\//') ]] && IMAGE_NAME="library/${IMAGE_NAME}" || IMAGE_NAME="${IMAGE_NAME}"
    TOKEN=$(curl -js "https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io" | jq -r .token 2>/dev/null)
  else
    TOKEN=$(curl -js "https://${IMAGE_URL}/v2/token" | jq -r .token)
  fi

  CONFIG_DIGEST=$(curl -s -H"Accept: application/vnd.docker.distribution.manifest.v2+json" -H"Authorization: Bearer ${TOKEN}" https://${IMAGE_URL}/v2/${IMAGE_NAME}/manifests/${IMAGE_TAG:=latest} | jq -r .config.digest 2>/dev/null)
  IMAGE_CONTENT=$(curl -sL -H"Authorization: Bearer ${TOKEN}" "https://${IMAGE_URL}/v2/${IMAGE_NAME}/blobs/${CONFIG_DIGEST}" | jq -r '.history | .[].created_by' 2>/dev/null | awk '{ print "\t" $0 }')

  echo -e "\x1b[0;34mDocker image '${IMAGE}' is created with the following commands:\x1b[0m"
  if [[ -z ${IMAGE_CONTENT} ]]; then
    echo -e "\x1b[1;31m\tImage not found!\x1b[0m\n\n"
  else
    echo -e "${IMAGE_CONTENT}\n\n"
  fi
done
