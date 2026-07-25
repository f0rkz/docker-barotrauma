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

## Server settings contract

Do not restore a whole-file `serversettings.xml` template. Barotrauma owns the
persisted document and updates it to the schema supported by the installed game
version. The entrypoint may update only explicitly mapped attributes.

When adding a server setting:

1. Add the environment variable and default to `.env.example`.
2. Add its canonical XML attribute and any legacy aliases to
   `serversettings.envmap`.
3. Update `docs/SERVER_SETTINGS.md` when precedence or migration behavior changes.
4. Extend `tests/settings.sh` to cover new merge behavior or aliases.
5. Verify that unmapped attributes and child elements remain intact.
