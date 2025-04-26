#!/bin/bash
set -e
export PORT_HTTP=7000
export APP_VERSION=$(date +"%y%M%d.%H%M%S")
echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
export FLASK_APP=./src/main.py
flask run  --port $PORT_HTTP
