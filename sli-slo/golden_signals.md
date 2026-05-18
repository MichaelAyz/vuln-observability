# Four Golden Signals — SLI Definitions

The Four Golden Signals—Latency, Traffic, Errors, and Saturation—are a framework introduced by Google Site Reliability Engineering (SRE) to measure the fundamental health of a user-facing system. They were identified as the most critical metrics because they closely mirror the actual user experience and provide the earliest warning signs of system degradation. In this stack, these signals form the foundation of our Service Level Objectives (SLOs), ensuring we measure what truly matters and set meaningful thresholds for alerting and performance evaluation.

---

## Section 1: Latency

**Definition:** Latency is how long it takes to serve a request. It is crucial to distinguish between the latency of successful requests and error requests. Failing fast (e.g., quickly returning an HTTP 500) can artificially lower the overall latency average, making the system appear faster while the user experience is actually degrading.

```promql
# p95 latency for successful requests (non-5xx)
histogram_quantile(0.95,
  rate(flask_http_request_duration_seconds_bucket{status!~"5.."}[5m])
)

# p95 latency for error requests (5xx only)
histogram_quantile(0.95,
  rate(flask_http_request_duration_seconds_bucket{status=~"5.."}[5m])
)
```

We use the 95th percentile (p95) rather than the average (mean) because averages hide the "tail latency." The tail represents the worst-experiencing users; if 5% of your users are experiencing 5-second load times while the rest experience 100ms, the average will still look healthy, but those 5% are having an unacceptable experience.

**SLO target preview:** `95% of successful requests complete under 500ms`

---

## Section 2: Traffic

**Definition:** Traffic measures how much demand the system is handling. For a web service, this is typically measured as requests per second (RPS).

```promql
# Request rate across all endpoints
rate(flask_http_request_total[5m])
```

Traffic is essential context for the other signals. It is used as the denominator in error rate calculations to establish the percentage of failures. It also gives context to saturation—high CPU utilisation at a low traffic volume indicates an underlying inefficiency or problem, whereas high CPU at peak traffic is expected scaling behaviour.

**SLO target preview:** `Used as denominator — no direct SLO target`

---

## Section 3: Errors

**Definition:** The rate of requests that fail. This covers explicit failures (e.g., HTTP 5xx Server Errors), implicit failures (e.g., returning a 200 OK but with corrupted or incorrect content), and policy failures (e.g., a request that succeeded but took too long and breached a timeout policy).

```promql
# Error rate as a ratio (used for SLO calculation)
rate(flask_http_request_total{status=~"5.."}[5m])
/
rate(flask_http_request_total[5m])

# Raw error count per second
rate(flask_http_request_total{status=~"5.."}[5m])
```

The ratio form (percentage of total traffic that fails) is what feeds directly into the SLO error budget calculation. A raw count of errors alone is meaningless without the context of traffic—100 errors per minute is disastrous if total traffic is 200 requests per minute, but completely negligible if total traffic is 1,000,000 requests per minute.

**SLO target preview:** `99% of requests succeed (error rate < 1%)`

---

## Section 4: Saturation

**Definition:** Saturation is a measure of how "full" the service is. It measures the resource utilisation that most constrains the service, such as CPU, memory, disk I/O, or network bandwidth. 

```promql
# CPU utilisation (%) — monitoring server
100 - (
  avg by(instance) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  ) * 100
)

# Memory utilisation (%)
(
  node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes
) / node_memory_MemTotal_bytes * 100

# Disk utilisation (%) — root filesystem
(
  node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}
) / node_filesystem_size_bytes{mountpoint="/"} * 100

# Network receive bytes per second
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Network transmit bytes per second
rate(node_network_transmit_bytes_total{device!="lo"}[5m])
```

Saturation is the leading indicator of system health. It predicts problems *before* they cause errors or latency spikes. For example, a service running at 95% memory utilisation will likely degrade or crash soon due to Out-Of-Memory (OOM) errors, even if it looks perfectly healthy and responsive right now.

**SLO target preview:** `CPU < 80% warning, < 90% critical. Memory < 80% warning, < 90% critical. Disk < 75% warning, < 90% critical.`

---

## Section 5: Blackbox Availability Signal

While not one of the original Four Golden Signals, Blackbox Availability is included here because it is the primary Service Level Indicator (SLI) for external availability. It measures exactly what a real user experiences when trying to access the production URL from outside the network.

```promql
# Availability — probe success rate over 30-day window
avg_over_time(probe_success{job="blackbox-http"}[30d])
```

This differs significantly from internal signals. A server might have completely healthy CPU and memory and show zero application errors, while simultaneously being completely unreachable to the public due to a misconfigured load balancer, expired SSL certificate, or DNS outage. A Blackbox probe catches these external failures; internal metrics like Node Exporter do not.

**SLO target preview:** `99.5% of HTTP probes return success over a rolling 30-day window`

---

## Section 6: Summary Table

| Signal | PromQL Expression | SLO Target | Alert Threshold |
|---|---|---|---|
| Latency (p95) | `histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket{status!~"5.."}[5m]))` | < 500ms | > 500ms for 5m |
| Traffic | `rate(flask_http_request_total[5m])` | N/A — context metric | N/A |
| Error Rate | `rate(flask_http_request_total{status=~"5.."}[5m]) / rate(flask_http_request_total[5m])` | < 1% | > 1% for 5m |
| CPU Saturation | `100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | < 80% | > 80% for 5m |
| Memory Saturation | `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100` | < 80% | > 80% for 5m |
| Disk Saturation | `(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100` | < 75% | > 75% for 5m |
| Availability | `avg_over_time(probe_success{job="blackbox-http"}[30d])` | > 99.5% | probe_success = 0 for 2m |
