# Resource downloads and releases

Each folder is a separate resource, with its own manifest version and license.
A repository tag does not mean every resource has a new release.

## Current downloads

As of 9 October 2026:

- Flashlite has published releases `v1.0.0` and `v1.0.1`.
  [Flashlite v1.0.1](https://github.com/Soldrynn/DaveDev-Public/releases/tag/v1.0.1)
  includes the `DaveDev_Flashlite.zip` asset.
- SFX is available from `main`; there is no separate SFX GitHub release yet.
  Its manifest says `2.0.0`. That is its source version, not a claim that a
  `2.0.0` release archive has been published.

To use SFX, download or clone the repository and copy only `DaveDev_SFX` into
your server's resources folder. Keep the folder name. For a reproducible source
copy, select and record the full commit before downloading or checking it out.
Follow the resource README for installation and supply audio as described there.

## Preparing a future release

1. Choose the resource and intended source commit. Check that its manifest
   version, release title and archive contents agree.
2. Use a resource-specific tag for new releases, such as
   `flashlite/v<version>` or `sfx/v<version>`. Existing `v1.0.0` and `v1.0.1`
   remain the historical Flashlite tags; do not move or rename them.
3. Run the static checks and test the resource in FiveM. Include that resource's
   README, license, manifest, scripts and assets in its archive. A source ZIP
   for the whole repository is different from an install-ready resource ZIP.
4. Record the full source commit and archive SHA-256 in the release notes.
   State what was tested and any installation changes. Check the archive by
   extracting it before publishing.
5. Review the draft release and publish it only after approval. Update the
   root download links and this page when the release is actually available.

There is no automatic release publishing in this repository's validation
workflow. These steps do not alter the terms of either resource's license.
