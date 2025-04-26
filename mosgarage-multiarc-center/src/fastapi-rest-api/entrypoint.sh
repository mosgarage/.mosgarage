#!/bin/bash
set -e

gunicorn --bind 0.0.0.0:${PORT_HTTP} -k uvicorn.workers.UvicornWorker main:app
