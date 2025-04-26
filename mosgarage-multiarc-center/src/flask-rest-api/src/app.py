import os
from flask import Flask
from datetime import datetime


app_version = os.getenv("APP_VERSION", "1.0.0.1")

app = Flask(__name__)

@app.route('/version', methods=['GET'])
def get_version(
) -> str:
    app_version = os.getenv("APP_VERSION", "1.0.0.1")
    return app_version
    
@app.route('/time', methods=['GET'])
def get_time(
) -> str:
    app_version = os.getenv("APP_VERSION", "1.0.0.1")
    now = datetime.utcnow()
    return now.strftime("%Y/%m/%d-%H:%M:%S")

