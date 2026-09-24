# Git Hooks

This directory contains git hooks for automatic validation.

## Setup

Enable hooks (one-time per clone):

```bash
git config core.hooksPath .githooks
```

## Hooks

- **pre-commit**: Runs `make test` before allowing commits

The hook clears Git's repository-specific environment variables before running
tests. This lets tests create disposable repositories and linked worktrees without
using the committing checkout's index, including during partial commits. See
[Git's hook environment guidance](https://git-scm.com/docs/githooks#_description).

## Bypass

When needed (emergency commits):

```bash
git commit --no-verify
```
