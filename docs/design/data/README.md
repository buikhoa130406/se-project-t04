# PA3 Data Design

- [Business data dictionary and concurrency design](data-dictionary.md)
- [Twelve-table business schema](schema.sql)
- [Original business-schema checks](schema-check.sql)
- [Business ERD](erd-overview.png)
- [Operational request replay table](api-request-result.sql), applied after the business schema.

The business schema/checks are preserved from PR #35 at `b4190dde4eae9af03530046b3e1c8a0b2093df02`. Trí reported 29/29 PostgreSQL 16 checks for that version. The separate api_request_result DDL and presence-based early-release design were added during Khoa’s integration; they have not been executed as application functionality. The business ERD intentionally shows twelve business tables; API-01 specifies the operational table and transaction protocol.
