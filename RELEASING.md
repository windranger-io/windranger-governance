# Releasing

## Trunk-based approach

The [development process](https://github.com/windranger-io/solidity-project-template/blob/a5fdabf7a8560f3ba076cb58f66f80768fbeca45/docs/development_process.md#branch-per-a-feature)
follows a trunk-based approach. The approach uses long-lived feature branches with ephemeral bug fix
branches. A key approach is to use tags on a branch and then deleting the branch; tagging a branch
allows the history to be maintained and accessible.

## Versioning

We follow [semantic versioning](https://semver.org/) guidelines. 

## Release Procedure

1. Checkout the branch or tag to update/release, assume `main`
2. Apply any updates and update CHANGELOG.md with the version number to be released
3. As part of updates, potentially create a bug fix branch
4. After completing updates, tag the branch with the release version label
    - alpha: `vn.n.n-alpha`, e.g., `v2.0.0-alpha`
    - beta: `vn.n.n-beta`, e.g., `v2.0.0-beta`
    - release candidate (RC): `vn.n.n-rc0`, e.g., `v2.0.0-rc0`,`v2.0.0-rc1`
    - point release: `vn.n.n`, e.g., `v2.0.1`, `v2.0.2`
5. Delete the bug fix branch
6. On github, select the tag as the release
7. Use the following template for the release notes:

```markdown
# windranger-governance v2.0.1 Release Notes

This is ALPHA software - use at your own risk. WARNING: unaudited software.

This release contains the initial specifications and corresponding smart contracts for governance
that will be proposed for BitDAO.
```

## Tagging

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

## Quick overview of creating a branch from a tag

To create a tag on a branch that is then deleted:
1. `git tag 'v2.0.1'`
2. `git branch -d my-bugfix` 
3. `git push 'v2.0.1'` or (as above) `git push --tags`

To create a branch from a tag (whose branch has been deleted):
1. `git fetch`
2. `git branch my-next-release 'v2.0.1'`
3. `git checkout my-next-release`
4. Apply updates, tag, then delete
