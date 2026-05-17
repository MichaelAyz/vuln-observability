import os
import json
import time
import logging
from datetime import datetime, timezone

from flask import Flask, jsonify, request, g

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource, SERVICE_NAME as RESOURCE_SERVICE_NAME
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from prometheus_flask_exporter import PrometheusMetrics

# OTel Logs SDK — sends structured logs via OTLP to the OTel Collector
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

# ── Environment ───────────────────────────────────────────────────────────────
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4328")
SERVICE_NAME  = os.getenv("OTEL_SERVICE_NAME", "vuln-watch-demo")

# ── OTel Resource (shared by traces and logs) ────────────────────────────────
resource = Resource.create({RESOURCE_SERVICE_NAME: SERVICE_NAME})

# ── OTel Tracer Setup ─────────────────────────────────────────────────────────
trace_exporter = OTLPSpanExporter(
    endpoint=f"{OTLP_ENDPOINT}/v1/traces",
)

provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(trace_exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(SERVICE_NAME)

# ── OTel Logger Setup ─────────────────────────────────────────────────────────
log_exporter = OTLPLogExporter(
    endpoint=f"{OTLP_ENDPOINT}/v1/logs",
)

log_provider = LoggerProvider(resource=resource)
log_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
set_logger_provider(log_provider)

# Attach OTel handler to Python logging — sends log records via OTLP
otel_handler = LoggingHandler(level=logging.INFO, logger_provider=log_provider)
logger = logging.getLogger("vuln-watch-demo")
logger.addHandler(otel_handler)
logger.setLevel(logging.INFO)

# ── Flask App ─────────────────────────────────────────────────────────────────
app = Flask(__name__)

# Auto-instrument all Flask routes — must happen after tracer provider is set
FlaskInstrumentor().instrument_app(app)

# Expose /metrics endpoint for Prometheus scraping
metrics = PrometheusMetrics(app)

# ── Helpers ───────────────────────────────────────────────────────────────────

def get_trace_id() -> str:
    """
    Return the current active trace ID as a zero-padded 32-character hex string.
    This matches the format Tempo stores and what the Loki derived field regex
    expects to extract and linkify.
    """
    span = trace.get_current_span()
    ctx  = span.get_span_context()
    if ctx.is_valid:
        return format(ctx.trace_id, "032x")
    return "0" * 32


# ── Request lifecycle hooks ───────────────────────────────────────────────────

@app.before_request
def _start_timer():
    g.start_time = time.time()


@app.after_request
def _log_request(response):
    """
    Emit a structured JSON log line after every request.
    Sent to both stdout (for journalctl) and via OTLP (for Loki).
    The traceId field is hex-formatted so the Loki derived field regex
    can extract it and open the trace directly in Tempo.
    """
    duration_ms = round((time.time() - g.start_time) * 1000, 2)
    log_entry = {
        "timestamp":   datetime.now(timezone.utc).isoformat(),
        "method":      request.method,
        "path":        request.path,
        "status_code": response.status_code,
        "duration_ms": duration_ms,
        "traceId":     get_trace_id(),
    }
    msg = json.dumps(log_entry)
    # stdout — visible in journalctl -u demo-service
    print(msg, flush=True)
    # OTLP — sent to OTel Collector → Loki (trace context auto-attached)
    logger.info(msg)
    return response


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return jsonify({
        "service": "vuln-watch-demo",
        "status":  "ok",
        "version": "1.0.0",
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/slow")
def slow():
    """
    Simulates high latency — sleeps 2 seconds before responding.
    Used in Game Day Scenario 2 (latency injection) to trigger
    the Latency SLI degradation and Fast Burn alert.
    """
    time.sleep(2)
    return jsonify({"status": "ok", "latency": "simulated"})


@app.route("/error")
def error():
    """
    Deliberately returns HTTP 500.
    Used in Game Day Scenario 1 (deployment failure) to drive up
    the Error Rate SLI and trigger the SLO burn rate alerts.
    """
    return jsonify({"status": "error", "message": "simulated error"}), 500


# ── Entrypoint ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, threaded=True)
