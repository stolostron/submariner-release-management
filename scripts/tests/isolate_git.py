"""Import first: keep test git commands away from the caller's repository.

Git hooks export GIT_DIR, GIT_INDEX_FILE and friends. Left in place, the
disposable repositories these tests create would resolve to the caller's
repository, and their `git config`/`git commit` calls would rewrite its
config (core.bare, core.hooksPath, user.*) and history.
"""

import os
import subprocess

for _name in subprocess.run(
    ["git", "rev-parse", "--local-env-vars"],
    check=True,
    stdout=subprocess.PIPE,
    text=True,
).stdout.split():
    os.environ.pop(_name, None)
for _name in [n for n in os.environ if n.startswith(("GIT_AUTHOR_", "GIT_COMMITTER_"))]:
    os.environ.pop(_name)
