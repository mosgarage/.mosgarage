#!/bin/bash
set -e
export FLASK_APP=./main.py
flask run  --host 0.0.0.0 --port ${PORT_HTTP}
