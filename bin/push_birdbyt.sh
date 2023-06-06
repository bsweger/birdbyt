#!/bin/sh

CURRENT_DIR=$( dirname -- "$0"; )
PARENT_DIR="${CURRENT_DIR%/*}"
echo $CURRENT_DIR

# set env variables
set -o allexport; source ${CURRENT_DIR}/.env; set +o allexport

# generate a webp image from the starlink script
echo 'Rendering birdbyt...'
pixlet render ${PARENT_DIR}/birdbyt.star ebird_api_key=${EBIRD_API_KEY} distance=${DISTANCE} back=${BACK}

# push the webp image to a designated tidbyt
echo 'Pushing birdbyt...'
pixlet push ${TIDBYT_ID} ${PARENT_DIR}/birdbyt.webp
mv ${PARENT_DIR}/birdbyt.webp ${CURRENT_DIR}

echo 'Done!'
