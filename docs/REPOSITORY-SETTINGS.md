# Repository settings checklist

These are settings to review in GitHub after the validation PR is available.
Adding this file does not change repository settings.

## Protect main

Once `FiveM static validation` has completed successfully on the PR's exact
commit, approve a ruleset for `main` with:

- Pull requests required before merging.
- `FiveM static validation` required, with the branch up to date before merge.
- Force pushes and branch deletion blocked.
- No required second-person approval for a solo-maintainer workflow. Add a
  reviewer requirement only when another reviewer is available.
- Any emergency bypass explicitly chosen and documented by the owner.

Select the actual check returned by GitHub after its first successful run.
Do not configure a check name that has never run. Review existing rules before
adding a new one so settings are not accidentally replaced.

## Private reports

Check whether GitHub private vulnerability reporting is enabled. If the owner
approves enabling it, verify that the repository Security page offers
**Report a vulnerability**, then update `SECURITY.md` to describe that route.
The policy file alone does not enable private reporting.
