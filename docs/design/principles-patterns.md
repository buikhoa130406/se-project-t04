## Design Principles and Patterns

Concurrency choices are documented in ADR-002.

| Principle / pattern | Where it is applied | Why |
| --- | --- | --- |
| PRI-01 • Separation of concerns | React screen logic and Express modules | The browser handles interaction while the server applies access and schedule rules. |
| PRI-02 • Single responsibility | Hold, booking, schedule block and notification responsibilities | A short-lived hold has its own lifecycle. A confirmed booking retains its own outcome. |
| PRI-03 • Dependency inversion | Services and repository interfaces | Business logic can be tested using substitute repositories, with SQL behind the repository interfaces. |
| PRI-04 • Reuse shared rules | Booking operations and owner schedule checks | In-person reservations use the shared hold and confirmation rules. Owner schedule changes use common checks. |
| PRI-05 • Least privilege and safe defaults | Access checks and hold workflow | Reject unauthorized actions and roll back the entire hold when any requested slot fails validation. |
| PAT-01 • Modular monolith | Express modules in one deployable process | Simplifies deployment and keeps schedule updates within one database boundary. |
| PAT-02 • Repository pattern | Data access under the service layer | Concentrates database queries and transaction handling behind shared interfaces. |
| PAT-03 • State-based lifecycle | STM-01, STM-02 and STM-03 | Explicit states and conditions make confirmation, cancellation and expiry rules reviewable. |
| PAT-04 • Atomic transaction | PostgreSQL transactions, row locks and GiST range exclusion on active shared schedule entries | A related set of checks and writes succeeds or rolls back together. One database exclusion constraint rejects overlapping active HOLD, BOOKING and BLOCK ranges. |
| PAT-05 • Expiry check and periodic worker | ReleaseJob and fixed expiry time | Confirmation checks expiry immediately. The worker releases expired holds. The five-second target is measured separately. |
