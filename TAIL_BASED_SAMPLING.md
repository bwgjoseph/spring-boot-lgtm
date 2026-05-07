# 📊 Tail-Based Sampling Guide

## Overview
Tail-based sampling is an advanced observability pattern that allows you to make informed decisions about which traces to keep *after* the entire trace has completed (at the "tail"), rather than at the start ("head"). 

This ensures that critical but infrequent events—like production errors or high-latency outliers—are captured at 100% frequency, while routine, successful requests are heavily sampled, significantly reducing storage costs.

---

## Architecture Requirements
1. **Clustered Ingestion:** Requires Grafana Alloy running in a clustered mode (multiple replicas with gossip protocol enabled).
2. **Trace Affinity:** Spans belonging to the same `trace_id` must be routed to the same Alloy instance. This is achieved via a `load_balancer` exporter that uses consistent hashing.
3. **Buffering:** Alloy pods must buffer spans for a configurable `decision_wait` window to allow all spans of a trace to arrive before making a sampling decision.

---

## Implementation Strategy

### 1. Load Balancing Exporter (Ensuring Affinity)
Configure the `otelcol.exporter.loadbalancing` component to group spans by `traceID` across the cluster nodes.

```alloy
otelcol.exporter.loadbalancing "lb" {
  protocol = "grpc"
  resolver {
    static { hostnames = ["alloy.monitoring.svc:4317"] }
  }
  routing_key = "traceID"
}
```

### 2. Tail Sampling Processor
Configure the `otelcol.processor.tail_sampling` component to apply policies.

```alloy
otelcol.processor.tail_sampling "sampling" {
  decision_wait = "5s" 
  
  // Policy 1: Always keep errors
  policy {
    name = "keep-errors"
    type = "status_code"
    status_code { status_codes = ["ERROR"] }
  }

  // Policy 2: Sample successful requests
  policy {
    name = "sample-success"
    type = "probabilistic"
    probabilistic { sampling_percentage = 5 } 
  }
}
```

---

## Recommended Next Steps
- [ ] Add `otelcol.exporter.loadbalancing` to the Alloy pipeline.
- [ ] Implement `otelcol.processor.tail_sampling` in `deployment/prod/values-alloy-local.yaml`.
- [ ] Tune `decision_wait` based on your application's average request latency.
- [ ] Validate trace retention metrics in Tempo to verify cost savings.
