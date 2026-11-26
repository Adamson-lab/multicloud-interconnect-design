# Multicloud Private Interconnect Design

Reference architecture and working infrastructure-as-code for private, dedicated connectivity between an enterprise estate and AWS (Direct Connect), Azure (ExpressRoute) and Google Cloud (Cloud Interconnect). Built for regulated, mission-critical estates: banks, Fortune 100 and Fortune 500 enterprises, federal agencies and parastatals.

> Repo About text: Working multicloud private interconnect blueprint (AWS Direct Connect, Azure ExpressRoute, GCP Cloud Interconnect) with Terraform, diagrams, resiliency maths and an executive decision model for regulated enterprises.

## Contents

1. Dual-metro topology across three clouds
2. Addressing and route-summarisation plan
3. BGP policy exchange across the fabric
4. Metro-A failure: failover sequence
5. Blast-radius map by failure domain
6. Interconnect operating-state machine
7. Traffic classes and QoS marking
8. Layered encryption and inspection path
9. Eighteen-month phased rollout
10. Change-approval governance gates
11. Annual run-cost composition
12. Option positioning: cost against resilience
13. Pattern selection decision tree
14. Telemetry and observability pipeline
15. Cutover experience for application owners

Terraform modules are in `terraform/`, the cost model in `tools/`, and ADRs in `docs/decisions.md`.

---

## 1. Dual-metro topology across three clouds

Two enterprise data centres home onto two colocation metros. Each metro hosts two carriers, so no single facility, carrier or cloud gateway carries all cross-cloud traffic.

```mermaid
flowchart TB
  subgraph ENT["Enterprise estate"]
    DCA["DC-A core (Tier IV)"]
    DCB["DC-B core (Tier IV)"]
    DRS["DR estate (warm standby)"]
  end

  subgraph MA["Metro A colocation"]
    A1["Carrier 1 meet-me room"]
    A2["Carrier 2 meet-me room"]
  end

  subgraph MB["Metro B colocation"]
    B1["Carrier 1 meet-me room"]
    B2["Carrier 2 meet-me room"]
  end

  subgraph AWS["AWS"]
    DXG["Direct Connect gateway"]
    TGW["Transit Gateway"]
  end

  subgraph AZ["Azure"]
    ERC["ExpressRoute circuit"]
    HUB["Hub VNet gateway"]
  end

  subgraph GCP["Google Cloud"]
    CI["Cloud Interconnect"]
    SVPC["Shared VPC"]
  end

  DCA --> A1
  DCA --> A2
  DCB --> B1
  DCB --> B2
  DRS -.-> A2
  DRS -.-> B2

  A1 -->|"10G LAG"| DXG
  B1 -->|"10G LAG"| DXG
  A2 -->|"10G LAG"| ERC
  B2 -->|"10G LAG"| ERC
  A1 -->|"VLAN attachment"| CI
  B2 -->|"VLAN attachment"| CI

  DXG --> TGW
  ERC --> HUB
  CI --> SVPC
```

## 2. Addressing and route-summarisation plan

Each cloud receives a single summary block from the enterprise supernet. Individual subnets stay internal, which keeps routing tables small and limits exposure to a route leak.

```mermaid
flowchart LR
  SUP["Enterprise supernet 10.0.0.0/8"]

  SUP --> AWSB["10.64.0.0/12 reserved for AWS"]
  SUP --> AZB["10.80.0.0/12 reserved for Azure"]
  SUP --> GCPB["10.96.0.0/12 reserved for GCP"]
  SUP --> ONP["10.0.0.0/12 on-premises"]
  SUP --> MGT["10.112.0.0/16 interconnect management"]

  AWSB --> AWSP["Prod 10.64.0.0/16"]
  AWSB --> AWSN["Non-prod 10.65.0.0/16"]
  AZB --> AZP["Prod 10.80.0.0/16"]
  AZB --> AZN["Non-prod 10.81.0.0/16"]
  GCPB --> GCPP["Prod 10.96.0.0/16"]
  GCPB --> GCPN["Non-prod 10.97.0.0/16"]

  MGT --> RTR["Router loopbacks 10.112.0.0/24"]
  MGT --> OOB["Out-of-band 10.112.1.0/24"]

  classDef summary fill:#1f3a5f,stroke:#0d1b2a,color:#ffffff
  classDef leaf fill:#e8f1fa,stroke:#5b7fa6,color:#0d1b2a
  class SUP,AWSB,AZB,GCPB,ONP,MGT summary
  class AWSP,AWSN,AZP,AZN,GCPP,GCPN,RTR,OOB leaf
```

## 3. BGP policy exchange across the fabric

The enterprise advertises summaries and rejects default routes from any cloud. Each cloud's session carries a maximum-prefix guard, so an accidental flood of routes shuts the session rather than polluting the core.

```mermaid
sequenceDiagram
  autonumber
  participant ENT as Enterprise edge (AS 64600)
  participant COLO as Colo meet-me router
  participant AWS as AWS DX gateway (AS 64512)
  participant AZ as Azure ER gateway (AS 12076)

  ENT->>COLO: Advertise 10.64.0.0/12 and 10.80.0.0/12
  COLO->>AWS: Forward summary, AS-path 64600
  COLO->>AZ: Forward summary, AS-path 64600
  AWS-->>COLO: Advertise 10.64.0.0/16 (prod only)
  AZ-->>COLO: Advertise 10.80.0.0/16 (prod only)
  COLO -x AWS: Default route 0.0.0.0/0 rejected by policy
  Note over COLO,AZ: Max-prefix guard: 200 routes per session
  ENT->>COLO: Keepalive every 10 s, hold timer 30 s
  COLO-->>ENT: Session established, preference Metro A
```

## 4. Metro-A failure: failover sequence

What happens when a whole colocation facility is lost, from detection through automatic reroute to restoration.

```mermaid
sequenceDiagram
  autonumber
  participant MON as Monitoring (synthetic probes)
  participant NOC as NOC on-call
  participant EDGE as Enterprise edge
  participant MB as Metro B path
  participant APP as Core banking replication

  Note over EDGE,APP: Steady state: Metro A preferred, Metro B standby
  MON->>MON: Loss above 2 percent for 3 probe cycles
  MON->>EDGE: BFD session down on Metro A
  EDGE->>EDGE: Withdraw Metro A routes (under 1 s)
  EDGE->>MB: Traffic shifts to Metro B (sub-second convergence)
  APP->>MB: Replication resumes, queue drains
  MON->>NOC: Page with incident template and carrier contact
  NOC->>MB: Confirm capacity at 130 percent of normal load
  NOC->>MON: Verify latency back to baseline within 5 minutes
  Note over EDGE,APP: Degraded but serving. RPO 0, RTO under 60 s
```

## 5. Blast-radius map by failure domain

Each row is a failure a board member would ask about, and the design control that contains it.

```mermaid
flowchart TB
  F1["Single fibre cut"] --> C1["LAG member removal"]
  F2["Cross-connect port failure"] --> C2["Second port on same metro"]
  F3["Metro facility outage"] --> C3["Full-capacity alternate metro"]
  F4["Carrier outage"] --> C4["Diverse carrier per metro"]
  F5["Cloud gateway failure"] --> C5["Second gateway per cloud"]
  F6["Route leak from partner"] --> C6["Prefix filter and max-prefix guard"]
  F7["Credential compromise on edge"] --> C7["Management plane isolated, MFA, PAM"]

  C1 --> R1["Impact: none"]
  C2 --> R2["Impact: none"]
  C3 --> R3["Impact: capacity headroom consumed, service held"]
  C4 --> R4["Impact: none for prod, reduced path diversity"]
  C5 --> R5["Impact: none for prod"]
  C6 --> R6["Impact: session torn down, scoped to one cloud"]
  C7 --> R7["Impact: contained, no lateral path to prod"]

  classDef risk fill:#fde8e8,stroke:#b42318,color:#401010
  classDef control fill:#e6f4ea,stroke:#1e7b34,color:#0f3d1a
  classDef result fill:#eef2ff,stroke:#3730a3,color:#1e1b4b
  class F1,F2,F3,F4,F5,F6,F7 risk
  class C1,C2,C3,C4,C5,C6,C7 control
  class R1,R2,R3,R4,R5,R6,R7 result
```

## 6. Interconnect operating-state machine

The operating state of each cloud path, with the transitions that move it between normal service, degraded service and declared incident.

```mermaid
stateDiagram-v2
  [*] --> Provisioning
  Provisioning --> Certified: Acceptance tests passed
  Certified --> Normal: Traffic cutover approved
  Normal --> Degraded: One path lost
  Degraded --> Normal: Path restored and verified
  Degraded --> Critical: Second path lost
  Critical --> Degraded: One path restored
  Critical --> Incident: Declared by NOC
  Incident --> PostReview: Service restored
  PostReview --> Normal: Actions closed and signed off
  Normal --> Maintenance: Approved change window
  Maintenance --> Normal: Change verified
```

## 7. Traffic classes and QoS marking

Traffic is classified at the edge and given a guaranteed share of the links. Replication and control traffic are protected even under saturation.

```mermaid
mindmap
  root((Interconnect QoS))
    Control plane
      BGP and BFD
      DSCP CS6
      Guaranteed 2 percent
    Critical replication
      Core banking sync
      DSCP EF
      Guaranteed 40 percent
    Customer transactions
      Payments and APIs
      DSCP AF41
      Guaranteed 35 percent
    Bulk and analytics
      Data lake loads
      DSCP AF11
      Best effort, capped 15 percent
    Backup
      Nightly snapshots
      DSCP CS1
      Scavenger, capped 8 percent
```

## 8. Layered encryption and inspection path

Every frame crosses three protection layers before it reaches a cloud boundary. Inspection happens on the enterprise side, where the security team controls the keys.

```mermaid
flowchart LR
  APP["Workload"] --> TLS["Application TLS 1.3"]
  TLS --> IPS["Inline IPS and DLP"]
  IPS --> IPSEC["IPsec tunnel AES-256-GCM"]
  IPSEC --> MACSEC["MACsec on 10G link AES-256"]
  MACSEC --> CARRIER["Carrier meet-me room"]
  CARRIER --> CLOUD["Cloud gateway"]
  CLOUD --> PRIV["Private VPC or VNet"]

  KMS["Enterprise KMS and HSM"] -.->|"keys rotated every 90 days"| IPSEC
  KMS -.->|"keys rotated every 90 days"| MACSEC
  SIEM["SIEM"] -.->|"flow and inspection logs"| IPS

  classDef layer fill:#eef2ff,stroke:#3730a3,color:#1e1b4b
  classDef control fill:#fff7e6,stroke:#b45309,color:#4a2505
  class TLS,IPSEC,MACSEC layer
  class IPS,KMS,SIEM control
```

## 9. Eighteen-month phased rollout

Phase 1 delivers the first metro and two clouds. Carrier lead times drive the critical path, so routing and monitoring work starts while circuits are being procured.

```mermaid
gantt
  title Multicloud interconnect rollout
  dateFormat YYYY-MM-DD
  axisFormat %b %Y

  section Governance
  Design authority sign-off      :done,    g1, 2027-01-04, 21d
  Risk acceptance and budget     :active,  g2, 2027-01-25, 45d
  Quarterly control reviews      :         g3, 2027-04-01, 480d

  section Procurement
  Carrier RFP and selection      :         p1, 2027-01-25, 60d
  Metro A circuits lead time     :         p2, after p1, 90d
  Metro B circuits lead time     :         p3, after p1, 105d

  section Build
  Routing and IP plan            :         b1, 2027-01-11, 40d
  Terraform modules hardened     :         b2, 2027-02-15, 45d
  Metro A cloud gateways         :         b3, after p2, 30d
  Metro B cloud gateways         :         b4, after p3, 30d

  section Cutover
  Non-prod pilot                 :         c1, after b3, 30d
  Prod cutover wave 1            :         c2, after c1, 21d
  Prod cutover wave 2            :         c3, after c2, 21d
  VPN sunset                     :crit,    c4, after c3, 30d
```

## 10. Change-approval governance gates

No change reaches production without passing each gate. Gates are enforced in the pull-request pipeline and recorded for audit.

```mermaid
flowchart TB
  START(["Change proposed as pull request"]) --> G1{"Terraform plan reviewed?"}
  G1 -- "No" --> REJ1["Returned to author"]
  G1 -- "Yes" --> G2{"Security scan clean?"}
  G2 -- "No" --> REJ2["Blocked: remediation required"]
  G2 -- "Yes" --> G3{"Non-prod test passed?"}
  G3 -- "No" --> REJ3["Blocked: fix in non-prod"]
  G3 -- "Yes" --> G4{"Risk owner approval?"}
  G4 -- "No" --> REJ4["Deferred to next board"]
  G4 -- "Yes" --> G5{"Inside approved change window?"}
  G5 -- "No" --> WAIT["Scheduled for window"]
  G5 -- "Yes" --> DEPLOY["Deploy with canary on one path"]
  DEPLOY --> VERIFY{"Canary healthy for 30 minutes?"}
  VERIFY -- "No" --> ROLL["Automatic rollback"]
  VERIFY -- "Yes" --> DONE(["Full rollout, evidence archived"])

  classDef gate fill:#eef2ff,stroke:#3730a3,color:#1e1b4b
  classDef stop fill:#fde8e8,stroke:#b42318,color:#401010
  classDef ok fill:#e6f4ea,stroke:#1e7b34,color:#0f3d1a
  class G1,G2,G3,G4,G5,VERIFY gate
  class REJ1,REJ2,REJ3,REJ4,WAIT,ROLL stop
  class DEPLOY,DONE ok
```

## 11. Annual run-cost composition

Illustrative split for a dual-metro, three-cloud design. Replace with contract figures before any funding decision.

<p align="center"><img src="docs/images/11-run-cost-composition.svg" alt="Annual run-cost composition pie chart" width="100%"></p>

## 12. Option positioning: cost against resilience

Where each connectivity option sits on the cost and resilience scale. The target quadrant is high resilience at a cost the business can defend.

```mermaid
%%{init: {"quadrantChart": {"chartWidth": 920, "chartHeight": 920, "titleFontSize": 30, "quadrantLabelFontSize": 24, "quadrantTextTopPadding": 18, "quadrantPadding": 50, "pointLabelFontSize": 20, "pointRadius": 9, "pointTextPadding": 10, "xAxisLabelFontSize": 22, "yAxisLabelFontSize": 22, "xAxisLabelPadding": 14, "yAxisLabelPadding": 14}}}%%
quadrantChart
  title Connectivity options for executive review
  x-axis Lower annual cost --> Higher annual cost
  y-axis Lower resilience --> Higher resilience
  quadrant-1 Premium resilience
  quadrant-2 Best value
  quadrant-3 Non-critical only
  quadrant-4 Costly and fragile
  "Internet VPN, single site": [0.12, 0.16]
  "Internet VPN, dual site": [0.24, 0.34]
  "Single metro dedicated": [0.36, 0.64]
  "Dual metro dedicated": [0.62, 0.72]
  "Dual metro + SD-WAN": [0.78, 0.84]
  "Carrier full mesh": [0.80, 0.60]
```

## 13. Pattern selection decision tree

A practical route from business requirement to interconnect pattern. Each leaf links to an ADR in `docs/decisions.md`.

```mermaid
flowchart TB
  Q1{"Does any workload carry regulated or critical data across clouds?"}
  Q1 -- "No" --> P1["Internet VPN with IPsec, ADR-002 exception"]
  Q1 -- "Yes" --> Q2{"Is downtime above 4 hours acceptable?"}
  Q2 -- "Yes" --> P2["Single metro dedicated circuits"]
  Q2 -- "No" --> Q3{"Are two facilities available within 100 km?"}
  Q3 -- "No" --> P3["Single metro with carrier diversity, documented risk acceptance"]
  Q3 -- "Yes" --> Q4{"More than three clouds or branch sites?"}
  Q4 -- "No" --> P4["Dual metro dedicated circuits, this reference design"]
  Q4 -- "Yes" --> P5["Dual metro plus SD-WAN overlay"]

  classDef q fill:#eef2ff,stroke:#3730a3,color:#1e1b4b
  classDef p fill:#e6f4ea,stroke:#1e7b34,color:#0f3d1a
  class Q1,Q2,Q3,Q4 q
  class P1,P2,P3,P4,P5 p
```

## 14. Telemetry and observability pipeline

Every path emits flow, routing and performance telemetry into one pipeline. Dashboards for the CIO and the regulator are generated from the same data the NOC uses, so the numbers agree.

```mermaid
flowchart LR
  subgraph SRC["Sources"]
    R1["Edge routers: BGP, BFD, interface"]
    R2["Cloud gateways: route and metric APIs"]
    R3["Synthetic probes: latency, loss, jitter"]
    R4["Firewalls: session and inspection logs"]
  end

  subgraph COL["Collection"]
    C1["Streaming telemetry gRPC"]
    C2["Cloud metrics exporters"]
  end

  subgraph PROC["Processing and storage"]
    P1["Stream processor, 1 s windows"]
    P2["Time-series store, 400 days"]
    P3["Immutable evidence bucket, WORM"]
  end

  subgraph OUT["Consumers"]
    O1["NOC dashboard and paging"]
    O2["CIO scorecard, monthly"]
    O3["Regulator evidence pack"]
  end

  R1 --> C1
  R2 --> C2
  R3 --> P1
  R4 --> P1
  C1 --> P1
  C2 --> P1
  P1 --> P2
  P1 --> P3
  P2 --> O1
  P2 --> O2
  P3 --> O3
```

## 15. Cutover experience for application owners

What an application owner lives through during a cutover, scored from calm (5) to stressful (1). The aim is that no owner ever scores below 3.

```mermaid
journey
  title Application owner cutover journey
  section Before
    Receives migration calendar: 4: Application owner
    Runs pre-check in non-prod: 4: Application owner, Platform team
    Signs off readiness checklist: 3: Application owner, Risk
  section Cutover window
    Canary traffic on one path: 4: Platform team
    Synthetic checks green: 5: NOC
    Full traffic moved: 4: Platform team, NOC
    Business transactions verified: 3: Application owner
  section After
    Post-cutover report issued: 5: Platform team
    Evidence pack filed: 4: Risk, Compliance
    Lessons logged to ADR: 4: Architecture board
```


