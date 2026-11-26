# Executive Brief: Multicloud Private Interconnect

**Decision requested:** Approve Phase 1 funding for dual-metro private connectivity to AWS, Azure and Google Cloud, and mandate a single governance model for all cloud network paths.

## The problem in one paragraph

Our critical services now span three clouds and two data centres. Traffic between them currently rides a mix of internet VPNs and ad hoc links. Those paths have no contractual latency or availability commitment, are hard to audit, and fail in ways we cannot predict. A single regional internet event could interrupt payments reconciliation, customer identity, or citizen-facing services, with consequences for customers, the regulator and the board.

## What we are proposing

Two independent colocation facilities in separate metros, each with dedicated private circuits to each of the three hyperscalers. Every circuit is provisioned with redundant links, route filtering, and monitoring. The design is captured as code, so the same controls are reproduced in each environment and can be evidenced to auditors.

## What it costs

Costs fall into three groups: fixed port and cross-connect fees, provider data-transfer charges, and one-time engineering. The companion model (`tools/Get-InterconnectModel.ps1`) produces the monthly and annual figures from our traffic profile, so the numbers update when volumes change. Figures in the repository are illustrative; the Finance-approved figures will come from signed carrier and cloud contracts.

## What it protects

| Scenario | Without this design | With this design |
|---|---|---|
| Single cable or port fault | Partial outage, manual intervention | Automatic reroute in seconds |
| Loss of one colocation facility | Full outage of cross-cloud paths | Traffic carried by second facility |
| Loss of one cloud region | Manual failover, unclear owner | Tested runbook, named owners, measured RTO |
| Routing mistake by a provider or team | Possible wide impact | Prefix filters and limits contain blast radius |

## Risks we are accepting

Dual-metro operation roughly doubles port fees compared with single-site designs. We accept that cost because a single-site failure would breach our service commitments. Carrier lead times of 8 to 16 weeks mean Phase 1 cannot be live before the next budget cycle; the design allows early work on routing and monitoring while circuits are procured.

## Governance and evidence

Every change goes through a pull request. Every circuit has a named owner, a documented failover test each quarter, and evidence retained for supervisory review. Control mapping is in `docs/regulatory-evidence.md`.

## Decisions requested today

1. Approve Phase 1 budget envelope, subject to contract validation.
2. Confirm the two colocation metros and carriers shortlisted by Procurement.
3. Mandate that all new cross-cloud traffic uses this interconnect after cutover, with a fixed sunset date for internet VPN paths.
