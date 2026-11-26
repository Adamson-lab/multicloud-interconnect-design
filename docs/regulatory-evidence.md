# Regulatory Evidence Map

This map links design controls to the evidence an auditor or supervisor will ask for. Adapt the control references to the framework applicable to your jurisdiction (for example PCI DSS, ISO/IEC 27001, NIST CSF, or national banking supervisory guidance).

| Control objective | Design control | Evidence artefact | Frequency |
|---|---|---|---|
| Resilience of critical services | Dual-facility interconnect | Quarterly failover test report | Quarterly |
| Confidentiality in transit | Dedicated private circuits, inspected and encrypted frames | Encryption configuration export | On change and annually |
| Change control | Terraform through pull requests | Merged PR history and plan output | Every change |
| Access control | Restricted state backend and role-based access | Access review record | Quarterly |
| Third-party risk | Named carrier and provider SLAs | Signed contracts and SLA reports | Annually |
| Incident response | Failover runbook | Incident records and post-incident reviews | Per incident |
| Route integrity | Prefix filters and max-prefix limits | Route policy configuration export | On change and monthly |

Reference: this table is a starting point and does not replace legal or regulatory advice.
