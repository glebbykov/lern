from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok", "service": "simple-web"})


@app.get("/")
def index():
    return "docker-lab simple web\n", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8090)
