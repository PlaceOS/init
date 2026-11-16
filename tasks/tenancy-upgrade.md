# Tenancy bootstrap upgrade safety

- [x] Obtain CI assertion failures for existing customer preservation and default bootstrap (1ce02b1, CI 43971923707).
- [x] Preserve customer ownership, names, configuration and grants on every normal startup.
- [x] Preserve fresh platform-management bootstrap privileges; refuse implicit legacy customer adoption.
- [ ] Verify formatting, lint, native semantic checks and GitHub CI.
