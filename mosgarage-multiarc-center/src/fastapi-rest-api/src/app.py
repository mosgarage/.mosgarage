import os

from fastapi import APIRouter, FastAPI, routing
from fastapi.params import Depends
from datetime import datetime
from starlette.requests import Request

router = APIRouter(prefix="")

app_version = os.getenv("APP_VERSION", "1.0.0.1")

app = FastAPI(
    title="Fastapi REST API",
    description="Sample Fastapi REST API.",
    version=app_version,
)

@router.get(
    "/version",
    responses={
        200: {"description": "Get version."},
    },
    summary="Returns the current version.",
)
def get_version(
    request: Request,
) -> str:
    app_version = os.getenv("APP_VERSION", "1.0.0.1")
    return app_version
    
@router.get(
    "/time",
    responses={
        200: {"description": "Get current time."},
    },
    summary="Returns the current time.",
)
def get_time(
    request: Request,
) -> str:
    app_version = os.getenv("APP_VERSION", "1.0.0.1")
    now = datetime.utcnow()
    return now.strftime("%Y/%m/%d-%H:%M:%S")

app.include_router(router, prefix="")

