FROM ubuntu:20.04

RUN apt-get -qq update && \
    apt-get install -y python3 python3-pip && \
        rm -rf /var/lib/apt/lists/* && \
        apt-get purge --auto-remove && \
        apt-get clean

RUN pip install flask

COPY application/app.py /opt/

ENTRYPOINT FLASK_APP=/opt/app.py flask run --host=0.0.0.0 --port=8080
