#!/bin/bash

# Usage: ./og-mirror.sh --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.15 --package=advanced-cluster-management --channel=release-2.11
# Usage with cache: ./og-mirror.sh --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.15 --package=advanced-cluster-management --channel=release-2.11 --cache=true

CACHE="false"
# Default configs directory
CONFIGS_DIR="/configs"

for i in "$@"; do
  case $i in
    --catalog=*)
      CATALOG="${i#*=}"
      shift # past argument=value
      ;;
    --package=*)
      PACKAGE="${i#*=}"
      shift # past argument=value
      ;;
    --channel=*)
      CHANNEL="${i#*=}"
      shift # past argument=value
      ;;
    --version=*)
      VERSION="${i#*=}"
      shift # past argument=value
      ;;
    --cache=*)
      CACHE="${i#*=}"
      shift # past argument=value
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

echo "CATALOG   = ${CATALOG}"
echo "PACKAGE   = ${PACKAGE}"
echo "CHANNEL   = ${CHANNEL}"
echo "VERSION   = ${VERSION}"
echo "CACHE     = ${CACHE}"

if [[ ${CACHE} == "false" ]]
then
  echo "not using cache"

  podman pull ${CATALOG}

  CONFIGS_DIR=$(podman inspect --format '{{index .Config.Labels "operators.operatorframework.io.index.configs.v1"}}' ${CATALOG})

  podman run -d --name catalog ${CATALOG}

  rm -rf ${CONFIGS_DIR}
  podman cp catalog:${CONFIGS_DIR} .

  podman stop catalog
  podman rm catalog
fi

if [[ ${CACHE} == "true" && ! -d .${CONFIGS_DIR} ]]
then
  echo "cache selected but no cache dir found"
  exit 1
fi

# TODO: Show related images
if [ ! -z ${VERSION} ]
then

  jq -r ". | select(.name==\"${VERSION}\").relatedImages[].image" .${CONFIGS_DIR}/${PACKAGE}/catalog.json

  exit 0
fi

# TODO: Show all available versions in this channel
if [ ! -z ${CHANNEL} ]
then
  VERSIONS=$(jq -c -r ". | select(.name==\"${CHANNEL}\").entries[].name" .${CONFIGS_DIR}/${PACKAGE}/catalog.json)
  echo -n "Versions: "
  echo ${VERSIONS}
  exit 0
fi

# TODO: Show all channels in this package
if [ ! -z ${PACKAGE} ]
then
  CHANNELS=$(jq -c -r '. | select(.schema=="olm.channel").name' .${CONFIGS_DIR}/${PACKAGE}/catalog.json)
  echo -n "Channels: "
  echo ${CHANNELS}
  exit 0
fi

# TODO: Show all operators in catalog
if [ ! -z ${CATALOG} ]
then
  OPERATORS=$(jq -c -r '. | select(.schema=="olm.package").name' .${CONFIGS_DIR}/*/catalog.json)
  echo "${OPERATORS}"
  exit 0
fi

#DEFAULT_CHANNEL=$(jq -c -r '. | select(.schema=="olm.package").defaultChannel' ./configs/${PACKAGE}/catalog.json)
