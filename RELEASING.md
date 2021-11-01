## Releasing Using a Long-Lived Version Branch Approach

### Release Procedure

1. Start on `main`
2. Update CHANGELOG.md
3. Create a new long-lived branch for each minor version. Create the `release/vn.n.x` branch,
   e.g., `release/v2.0.x`. It is fine to create a long-lived branch from main if the last commit is
   the release commit.
4. Tag the release
    - alpha: `vn.n.n-alpha`, e.g., `v2.0.0-alpha`
    - beta: `vn.n.n-beta`, e.g., `v2.0.0-beta`
    - release candidate (RC): `vn.n.n-rc0`, e.g., `v2.0.0-rc0`,`v2.0.0-rc1`
    - point release: `vn.n.n`, e.g., `v2.0.1`, `v2.0.2`
5. On github, select the tag as the release
6. Use the following template for the release notes:

```markdown
# windranger-governance v2.0.1 Release Notes

This is ALPHA software - use at your own risk. WARNING: unaudited software.

This release contains the initial specifications and corresponding smart contracts for governance
that will be proposed for BitDAO.
```

### Point Release Procedure

1. Start on the long-lived `release/vn.n.x` branch
2. Cherry-pick commits from `main`
3. Tag the release with the point version, e.g., `vn.n.n+1`
4. Update the CHANGELOG.md

### Tagging

The following steps are the default for tagging a specific branch commit (usually on a branch
labeled `release/vn.n.n`):

1. Ensure you have checked out the commit you wish to tag
1. `git pull --tags --dry-run`
1. `git pull --tags`
1. `git tag -a v2.0.1 -m 'Release v2.0.1'`
1. optional, add the `-s` tag to create a signed commit using your PGP key (which should be added to
   github beforehand)
1. `git push --tags --dry-run`
1. `git push --tags`

To re-create a tag:

1. `git tag -d v2.0.0` to delete a tag locally
1. `git push --delete origin v2.0.0`, to push the deletion to the remote
1. Proceed with the above steps to create a tag

To tag and build without a public release (e.g., as part of a timed security release):

1. Follow the steps above for tagging locally, but do not push the tags to the repository.
2. After adding the tag locally, you can build the repo
3. Push the local tags
4. Create a release based off the newly pushed tag 


