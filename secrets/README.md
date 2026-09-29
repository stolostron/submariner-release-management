# Team Secrets

## `entitlements.asc`

The team's shared Red Hat org ID and activation key (and optionally a shared
`registry.redhat.io` login), sealed with GnuPG symmetric encryption (AES-256,
salted iterated SHA-512 key derivation, integrity-protected). One long random team
password opens it. It is committed to this **public** repo on purpose; see
[Why it exists](#why-it-exists) and [Security position](#security-position).

- Use: `make setup-entitlements` (asks for the team password once, can remember it).
- Check: `make check-entitlements`.
- Create or rotate (key holder only): `make seal-entitlements`.
- The team password is shared out of band and never committed.

## Why it exists

`rpm-lockfile-update` (release step 4b) and the Konflux RPM lockfile builds need RHEL
content, which needs a machine registered with Red Hat entitlements: an org ID plus an
activation key, registered via `subscription-manager`. Upstream's documented flow has
each person create their own activation key
([shipyard `.rpm-lockfiles`](https://github.com/submariner-io/shipyard/tree/devel/.rpm-lockfiles)).

That does not work well for us:

- Red Hat's activation-key page (`console.redhat.com/insights/connector/activation-keys/`)
  fails to load or errors intermittently for very large internal Red Hat accounts, because
  so many keys exist on the account. A known, low-priority Red Hat backlog item; it is not
  expected to be fixed soon. Some teammates cannot reach the page at all, which blocks
  them from producing RPM lockfiles and therefore from Konflux builds.
- Red Hat's subscription team says the design intent is to **share** keys: an activation
  key registers a system with preconfigured content, so one per org (or at least one per
  team) is enough, and users just need the org ID and key name. One key per person is
  what filled the account up.

So the team uses one shared org ID and activation key, and this bundle is how it gets to
each teammate with a one-command setup instead of a hunt through a broken web page.

## Security position

Recorded so agents and reviewers do not reopen it (also in `CLAUDE.md`, "Settled Decisions"):

- The org ID and activation key are two secret strings that together are sufficient to
  register a machine and read the org's subscription content. Red Hat's subscription team
  describes an activation key as comparable to an OpenShift pull secret: minimally scoped
  and useless without the org ID.
- Asking each team to run its own shared-secret handling is a weaker model than central
  secret management. The maintainer raised this with Red Hat's subscription team, asked for
  a security sign-off and for the plan to fix the page, and got no formal sign-off (that
  team has no designated security contact for this). The maintainer's position: it weakens
  the threat model, but the team accepted the risk in exchange for usability.
- Decision: the sealed bundle stays in the public repo. Priority is a one-command setup.
  Do not re-ask about moving it private or distributing it out of band.
- Mitigations: the bundle is encrypted with a 64-character random password (passwords
  under 43 characters are refused); the password is never committed; gpg runs against a
  throwaway keyring.
- Limits: anyone who has ever had the password can read old copies of the bundle from git
  history. **To remove someone's access, rotate the activation key itself** (create a new
  key in Red Hat's console, then `make seal-entitlements`); changing only the password is
  not enough. The key is also briefly visible in `ps` while `subscription-manager` runs.
