ARG ARG_PORT_HTTP=8000
ARG ARG_APP_VERSION="1.0.0.1"
# stage 1
FROM tiangolo/uvicorn-gunicorn-fastapi:python3.8-slim AS build-image

WORKDIR /src
COPY ./requirements.txt ./
COPY ./setup.py ./
COPY ./src/ ./src
RUN pip install -r requirements.txt
RUN PYTHONPATH=./src python3 -m setup bdist_wheel

# stage 2
FROM tiangolo/uvicorn-gunicorn-fastapi:python3.8-slim AS release-image
ARG ARG_PORT_HTTP
ENV PORT_HTTP ${ARG_PORT_HTTP}

ARG ARG_APP_VERSION
ENV APP_VERSION=${ARG_APP_VERSION}

WORKDIR /app

COPY --from=build-image ./src/dist/*.whl /app/packages/
COPY ./src/app.py /app
COPY ./src/main.py /app
COPY ./entrypoint.sh /app
RUN chmod +x ./entrypoint.sh

RUN python -m pip install packages/*.whl
EXPOSE $PORT_HTTP/tcp

CMD ["./entrypoint.sh"]
