# Architecture Decision Records

## ADR-001: Two colocation facilities instead of one

**Status:** Accepted
**Context:** A single facility is a single point of failure for all cross-cloud traffic.
**Decision:** Deploy in two metros with independent carriers.
**Consequence:** Port fees roughly double. Accepted, because the alternative breaches service commitments on facility loss.

## ADR-002: Dedicated circuits over internet VPN for production

**Status:** Accepted
**Context:** Internet VPN has no latency or availability commitment and is harder to audit.
**Decision:** Dedicated circuits carry production. VPN remains as documented backup only.
**Consequence:** Longer lead times and higher fixed cost.

## ADR-003: Terraform as the single source of truth

**Status:** Accepted
**Context:** Manual configuration across three clouds produces drift and audit gaps.
**Decision:** All interconnect resources are declared in this repository and deployed through reviewed pull requests.
**Consequence:** Requires Terraform skills and a state backend with access control.

## ADR-004: Advertise summaries only

**Status:** Accepted
**Context:** Advertising detailed prefixes exposes internal topology and increases table size.
**Decision:** Advertise summarised RFC1918 blocks. Reject default routes from clouds.
**Consequence:** Requires disciplined IP address management.
