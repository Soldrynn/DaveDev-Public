# Security reports

Please keep vulnerability details out of public issues, pull requests and Discord
channels. Do not include passwords, tokens, server connection details or player
data in a report.

## Contact

Email vulnerability reports privately to
[davedev.store@gmail.com](mailto:davedev.store@gmail.com).

If the [repository Security page](https://github.com/Soldrynn/DaveDev-Public/security)
shows **Report a vulnerability**, you can also use that private form. The
presence of this policy does not mean GitHub private reporting is enabled.

## What to include privately

- The resource name and version from `fxmanifest.lua`.
- The release tag or full source commit, and any local changes.
- A short description of the impact and steps to reproduce on a test server.
- Relevant logs with secrets, addresses and player information removed.

The current source on `main` is the starting point for investigating reports.
Please identify older versions too if they are affected. There is no published
long-term support or security-backport schedule, and this policy does not
promise a response deadline.

This repository contains Flashlite and SFX. For an issue in FiveM, FXServer or
another resource, use that project's reporting route.
