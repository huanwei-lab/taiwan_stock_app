Release 2026-03-01

Summary:
- Fix analyzer warnings and clean debug output
- Replace prints with stdout.writeln
- Add fund-flow EOD ingestion, cache, scheduler
- Add intraday polling service and controller
- Wire notifications and tests

Files changed in last commit:
$(git diff --name-only HEAD~1 HEAD -r)

All unit tests passing locally.
