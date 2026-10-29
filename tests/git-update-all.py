#!/usr/bin/env python3
"""Exercise git_update_all against disposable local Git repositories."""

import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "terminal/.zshrc").read_text()
# Load only the two function definitions; do not execute interactive startup.
HELPER = SOURCE.split("function _require_cmd() {", 1)[1].split("\n}", 1)[0]
FUNCTION = SOURCE.split("function git_update_all() {", 1)[1].split("\n}", 1)[0]
SCRIPT = (
    "function _require_cmd() {" + HELPER + "\n}\n"
    "function git_update_all() {" + FUNCTION + "\n}\n"
    'git_update_all "$@"\n'
)


with tempfile.TemporaryDirectory(prefix="git-update-all-") as temporary:
    base = Path(temporary)
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update(
        GIT_CONFIG_NOSYSTEM="1",
        GIT_CONFIG_GLOBAL=os.devnull,
        GIT_TERMINAL_PROMPT="0",
        GIT_AUTHOR_NAME="Test",
        GIT_AUTHOR_EMAIL="test@example.invalid",
        GIT_COMMITTER_NAME="Test",
        GIT_COMMITTER_EMAIL="test@example.invalid",
    )

    def git(repo, *args):
        return subprocess.check_output(
            ["git", "-C", str(repo), *args], env=env, text=True,
            stderr=subprocess.PIPE,
        ).strip()

    def run(*args):
        return subprocess.run(
            ["zsh", "-f", "-c", SCRIPT, "git-update-all", *map(str, args)],
            cwd=base, env=env, text=True, capture_output=True,
        )

    remote = base / "remote.git"
    seed = base / "seed"
    folder = base / "repos with spaces"
    folder.mkdir()
    git(base, "init", "--bare", "--initial-branch=main", str(remote))
    git(base, "clone", str(remote), str(seed))
    (seed / "file").write_text("initial\n")
    git(seed, "add", ".")
    git(seed, "commit", "-m", "initial")
    git(seed, "push", "-u", "origin", "main")
    original = git(seed, "rev-parse", "HEAD")
    names = [
        ".hidden", "clean repo", "dirty", "staged", "untracked", "detached",
        "no-upstream", "busy", "diverged", "ahead", "network-error",
    ]
    repos = {}
    for name in names:
        repos[name] = folder / name
        git(base, "clone", str(remote), str(repos[name]))

    for name in ("dirty", "staged"):
        (repos[name] / "file").write_text("local changes\n")
    git(repos["staged"], "add", ".")
    (repos["untracked"] / "new file").write_text("keep me\n")
    git(repos["detached"], "checkout", "--detach")
    git(repos["no-upstream"], "branch", "--unset-upstream")
    (repos["busy"] / ".git" / "MERGE_HEAD").write_text(original + "\n")
    (repos["diverged"] / "local").write_text("diverged")
    git(repos["diverged"], "add", ".")
    git(repos["diverged"], "commit", "-m", "local commit")
    git(repos["network-error"], "remote", "set-url", "origin", str(base / "missing"))
    git(repos["clean repo"], "config", "pull.rebase", "true")
    git(repos["clean repo"], "config", "rebase.autoStash", "true")

    # Linked worktrees use a .git file instead of a directory.
    worktree = folder / "worktree"
    git(seed, "worktree", "add", "-b", "linked", str(worktree), "origin/main")
    nested = folder / "ordinary" / "nested"
    nested.parent.mkdir()
    git(base, "clone", str(remote), str(nested))
    git(base, "init", "--bare", str(folder / "bare.git"))

    (seed / "file").write_text("remote update\n")
    git(seed, "commit", "-am", "remote update")
    git(seed, "push")
    latest = git(seed, "rev-parse", "HEAD")
    git(repos["ahead"], "pull", "--ff-only")
    (repos["ahead"] / "local").write_text("local commit ahead of upstream")
    git(repos["ahead"], "add", ".")
    git(repos["ahead"], "commit", "-m", "local commit")
    unchanged = {name: (
        git(repos[name], "rev-parse", "HEAD"),
        git(repos[name], "status", "--porcelain", "--untracked-files=all"),
    ) for name in names if name not in (".hidden", "clean repo")}

    result = run(folder)
    assert result.returncode == 1, result.stdout + result.stderr
    for repo in (repos[".hidden"], repos["clean repo"], worktree):
        assert git(repo, "rev-parse", "HEAD") == latest, result.stdout + result.stderr
    for name, snapshot in unchanged.items():
        assert snapshot == (
            git(repos[name], "rev-parse", "HEAD"),
            git(repos[name], "status", "--porcelain", "--untracked-files=all"),
        ), name
    assert git(nested, "rev-parse", "HEAD") == original
    assert (repos["busy"] / ".git" / "MERGE_HEAD").read_text() == original + "\n"
    assert (repos["dirty"] / "file").read_text() == "local changes\n"
    assert (repos["staged"] / "file").read_text() == "local changes\n"
    assert (repos["untracked"] / "new file").read_text() == "keep me\n"
    assert "Repositorios: 12 | Al día/actualizados: 4 | Omitidos: 6 | Errores: 2" in result.stdout, result.stdout + result.stderr

    empty = base / "empty"
    empty.mkdir()
    assert run(empty).returncode == 0
    assert run().returncode == 0  # Defaults to the current directory.
    assert run(base / "missing").returncode == 1
    assert run(empty, empty).returncode == 1
    assert run("--help").returncode == 0

print("ok: fast-forward, worktrees, hidden paths, local changes, divergence and failures")
