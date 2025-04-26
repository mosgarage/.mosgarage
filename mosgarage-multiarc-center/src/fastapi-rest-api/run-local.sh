#!/bin/bash
set -e
export PORT_HTTP=7000
export APP_VERSION=$(date +"%y%M%d.%H%M%S")
echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
PYTHONPATH=./src uvicorn main:app --reload --port ${PORT_HTTP}
