# Architecture

## Design principles

1. **Two facilities, two carriers, no shared fate.** No single facility, carrier or cloud control plane may take down all cross-cloud paths.
2. **Private by default.** Dedicated circuits carry production traffic. Internet VPN is a documented backup only.
3. **Least route exposure.** Each cloud sees only the prefixes it needs. Default routes are never advertised across the interconnect.
4. **Everything as code.** Circuits, routing policy and gateways are declared in Terraform and reviewed like application code.
5. **Measured, not assumed.** Latency, loss and failover time are monitored and reported monthly to the CIO.

## Traffic flows

```mermaid
sequenceDiagram
  participant App as Core banking app (DC-A)
  participant FW as Inspection firewall
  participant Colo as Colo-A cross-connect
  participant DX as AWS Direct Connect
  participant TGW as Transit Gateway
  participant VPC as Prod VPC (AWS)

  App->>FW: Replication request
  FW->>Colo: Inspected, encrypted frame
  Colo->>DX: Dedicated 10 Gbps path
  DX->>TGW: BGP-learned route
  TGW->>VPC: Delivered to workload
  Note over Colo,DX: Failure of Colo-A reroutes via Colo-B within BGP convergence time
```

## Routing policy

```mermaid
flowchart LR
  subgraph Policy["Route policy applied at each edge"]
    P1["Advertise only RFC1918 summaries"]
    P2["Reject default route from cloud"]
    P3["Max-prefix limit per session"]
    P4["AS-path prepend on Colo-B to prefer Colo-A"]
  end
  P1 --> P2 --> P3 --> P4
```

## Failover sequence

```mermaid
stateDiagram-v2
  [*] --> Normal
  Normal --> Degraded: Colo-A session down
  Degraded --> Normal: Colo-A restored
  Degraded --> Critical: Colo-B also down
  Critical --> Degraded: Colo-B restored
  Critical --> Declared: Incident declared, runbook started
  Declared --> [*]: Service restored and post-incident review
```

## Capacity model

Each facility is sized to carry 100 percent of peak cross-cloud traffic on its own, with headroom of 30 percent. Use `tools/Get-InterconnectModel.ps1` to recalculate when traffic forecasts change.

## Known limits

- Cross-cloud latency is bounded by physical distance; target figures must be validated per metro pair.
- Provider SLAs differ. The design uses the lower of the two commitments as the planning baseline.
- Carrier diversity depends on physical route audits, which must be repeated annually.
