# PA3 Software Design

Compiled CourtConnect PA3 for team review, 23 November 2026.

- [PDF](T04-PA3.pdf)
- [Editable Word document](T04-PA3-SoftwareDesign.docx)
- [Review checklist](../../docs/design/review/pa3-submission-review.md)

## Source designs

| Content | Source |
|---|---|
| Design overview | [Overview](../../docs/design/design-overview.md) |
| Architecture | [Architecture](../../docs/design/architecture/architecture-design.md) |
| ADRs | [ADR-001](../../docs/design/adr/ADR-001.md), [ADR-002](../../docs/design/adr/ADR-002.md), [ADR-003](../../docs/design/adr/ADR-003.md) |
| Interfaces | [API and module contracts](../../docs/design/interfaces/api-contract.md) |
| Object-oriented design | [Domain](../../docs/design/domain/domain-model.md), [Classes](../../docs/design/classes/class-design.md), [Sequences](../../docs/design/sequences/sequence-diagrams.md), [States](../../docs/design/states/state-machines.md) |
| Principles and patterns | [Patterns](../../docs/design/principles-patterns.md) |
| Data | [Dictionary, schema and checks](../../docs/design/data/README.md) |
| UI | [Screen specifications and mockups](../../docs/design/ui/ui-design-specification.md) |
| Traceability and changes | [Traceability](../../docs/design/traceability.md), [Changes since PA2](../../docs/design/requirements-changes.md) |
| Editable diagrams | [Source index](../../docs/design/diagram-sources/README.md) |
| AI usage | [Khoa](../../docs/ai-usage/PA3/24127421-khoa.md), [Trí](../../docs/ai-usage/PA3/24127569-tri.md), [Vĩ](../../docs/ai-usage/PA3/24127587-vi.md) |

The Markdown specifications and figure exports reflect the integrated Word document, including the aligned ID types, FACILITY_OWNER role, notification read state, historical snapshots and price-at-slot rules. Contributor PRs remain available as development and review history; this PR adds their consolidated result without merging the feasibility spike.

## Integration inputs

| Content | Pull request |
|---|---|
| Khoa ADR and traceability | #25 |
| Trí overview, domain, sequence and state | #24, #26, #27, #28 |
| Vĩ UI, architecture, classes and patterns | #29, #30, #31, #32 |
| Vĩ interface design replacing the undelivered task #12 | #34 (`fe55c40115d3c8fa54d9975c1208598e9e96d7c4`) |
| Trí data design replacing the undelivered task #10 | #35 (`b4190dde4eae9af03530046b3e1c8a0b2093df02`) |

The contribution assessment is Khoa 30%, Trí 35%, Vĩ 35%, Khôi 0%. The final merge and course submission follow the members' review of this compiled version.

## Integration consistency revision 23 November

Khoa authorised completing the report’s internal consistency without another member-edit cycle. Class/API/sequence terminology and effective-dated pricing are aligned; the current UI figures are PA3 SVG wireframes. FR-26 now specifies volatile presence heartbeat with early release and fixed-expiry fallback. API-01 specifies the separate operational replay table in `docs/design/data/api-request-result.sql`. The twelve-table business schema remains unchanged.

These choices are documented integration work by Khoa and are not described as approved by Trí/Vĩ or implemented/tested runtime features. The updated Word/PDF is 77 pages. The review note records the scope and verification; the feasibility spike is not included in this branch.
