import os
import logging
from flask import Flask, jsonify, request
from flask_cors import CORS
import redis
from datetime import datetime
import socket
from redis.retry import Retry
from redis.backoff import ExponentialBackoff

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Redis configuration - with password support
REDIS_HOST = os.environ.get("REDIS_HOST", "redis-master")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", None)


redis_client = None


def get_redis_client():
    global redis_client
    if redis_client is None:
        try:
            # Create Redis client with retry logic
            client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                password=REDIS_PASSWORD,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
                retry=Retry(
                    ExponentialBackoff(), 3
                ),  # Retry 3 times with exponential backoff
                health_check_interval=30,  # Check connection health every 30 seconds
            )

            # Test the connection
            client.ping()
            redis_client = client
            logger.info(f"Successfully connected to Redis at {REDIS_HOST}:{REDIS_PORT}")

        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            redis_client = None

    return redis_client


@app.route("/", methods=["GET", "POST"])
def counter():
    """
    GET: Returns current counter value
    POST: Increments counter and returns new value
    """
    client = get_redis_client()
    if not client:
        return jsonify({"error": "Redis unavailable"}), 503
    try:
        if request.method == "POST":
            new_value = client.incr("counter")
            logger.info(f"Counter incremented to {new_value}")
            return jsonify(
                {
                    "counter": new_value,
                    "hostname": socket.gethostname(),
                    "timestamp": datetime.utcnow().isoformat(),
                }
            )
        else:
            value = client.get("counter")
            current = int(value) if value else 0
            return jsonify(
                {
                    "counter": current,
                    "hostname": socket.gethostname(),
                    "timestamp": datetime.utcnow().isoformat(),
                }
            )
    except redis.RedisError as e:
        logger.error(f"Redis error: {e}")
        return jsonify({"error": "Service temporarily unavailable"}), 503


@app.route("/ready")
def ready():
    try:
        # Test Redis connection
        redis = get_redis_client()
        redis.ping()
        return jsonify({"status": "ready"}), 200
    except Exception as e:
        return jsonify({"status": "not ready", "error": str(e)}), 503


@app.route("/health")
def health():
    """Liveness check - app is alive but may not be ready"""
    # This should only check if the app process is running
    # Don't check Redis here - we want the pod to stay alive even if Redis is down
    return jsonify({"status": "healthy"}), 200


@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    client = get_redis_client()
    counter_value = client.get("counter")
    return (
        f"""# HELP counter_value Current counter value
# TYPE counter_value gauge
counter_value {counter_value}
""",
        200,
        {"Content-Type": "text/plain; charset=utf-8"},
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
    # test CI workflow
