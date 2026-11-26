# Runbook: Interconnect Failover

**Owner:** Network Operations. **Escalation:** Cloud Platform lead, then CIO on-call.

## Detection

Monitoring raises an alert when a BGP session drops or latency exceeds the agreed threshold for five consecutive minutes.

## Immediate actions (first 15 minutes)

1. Confirm which session is down: `Colo-A`, `Colo-B`, or a specific cloud VIF.
2. Confirm traffic has moved to the surviving path by checking the route table on the surviving edge.
3. If traffic has not moved, withdraw the failed path manually using the change ticket template.
4. Open an incident and notify the service owners of affected workloads.

## Carrier engagement

Open a carrier ticket with the circuit ID and the fault time. Record the carrier reference in the incident.

## Recovery

1. Restore the failed path only after the carrier confirms physical repair.
2. Re-enable BGP sessions in staged order: one VIF, then observe for 30 minutes, then the next.
3. Confirm route preference returns to the designed primary.

## Post-incident

Complete the post-incident review within five business days. Record measured RTO and RPO against targets in `docs/regulatory-evidence.md`.
