# Agent Development Instructions

This repository uses Conventional Commits, semantic PR titles, and
semantic-release. Future agent work must preserve those standards so releases
and container tags are generated correctly.

## Commit and PR title format

Use `type(scope): short imperative summary`. Accepted types are `feat`, `fix`,
`docs`, `test`, `ci`, `build`, `refactor`, `perf`, `style`, `chore`, and `revert`.
Use a `BREAKING CHANGE:` footer for incompatible behavior.

`feat` creates a minor release, `fix` creates a patch release, and a breaking
change creates a major release. Other types normally do not publish a release.

## Before committing or opening a PR

1. Confirm the commit and PR title use the semantic format.
2. Use a release-producing type only when a new image should be published.
3. Put issue references in the PR body.
4. Run relevant tests or document why they could not be run.
