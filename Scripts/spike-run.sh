#!/bin/sh
# Spike only: runs the app with the DVR login from the Keychain item
# com.carloseduardo.IntelbrasViewer.spike in its environment, plus any
# launch arguments given (e.g. -spikeWindow YES -spikeChannel 2).
set -eu
SERVICE=com.carloseduardo.IntelbrasViewer.spike
APP=${APP:-DerivedData/Build/Products/Debug/IntelbrasViewer.app/Contents/MacOS/IntelbrasViewer}
SPIKE_DVR_USER=$(security find-generic-password -s "$SERVICE" | sed -n 's/.*"acct"<blob>="\(.*\)"/\1/p')
SPIKE_DVR_PASSWORD=$(security find-generic-password -s "$SERVICE" -w)
export SPIKE_DVR_USER SPIKE_DVR_PASSWORD
exec "$APP" "$@"
