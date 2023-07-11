import os
from flask import Flask

app = Flask(__name__)


@app.route("/")
def main():
    return "Welcome to the simple app!"


@app.route('/how_are_you')
def hello():
    return 'Hey! I am good!'


if __name__ == "__main__":
    app.run()
