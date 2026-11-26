# PA3 integration consistency check

## Scope and authority

On 23 November 2026, Khoa authorised resolving the compiled report’s internal contradictions without waiting for another member-edit cycle. This pass targets a coherent PA3 submission, not an Excellent-level redesign. Contributor task ownership and contribution percentages are unchanged. These integration choices are not represented as already approved by Trí or Vĩ.

## Changes

- Aligned the compact class specifications with effective-dated slot pricing and documented sequence participant/method aliases against the existing API/module contracts.
- Replaced inherited UI images with editable PA3 wireframes using email/password, one sport per facility, automatic confirmation and in-app notices.
- Closed FR-26 with authenticated 10-second heartbeats and best-effort early release after 30 seconds of missing known presence. Reload resumes the same hold; unknown presence after restart falls back to fixed expiry. The worker and release-state description agree.
- Specified api_request_result as operational PostgreSQL storage outside the twelve business tables, with per-key coordination and atomic business-action/result commit. The original schema and its reported test results are not relabelled as tests of these additions.

## Verification

The final Word/PDF and exported Markdown specifications must match; preserve 57 traceability rows, 12 business tables/73 columns, 3 Proposed ADRs, 15 screen figures and contribution total 100%. Check page layout and relative source links. No implementation, load test, or new runtime-performance result is claimed. The feasibility spike stays on PR #36’s separate branch.
