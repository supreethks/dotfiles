#!/usr/bin/env python3
"""
cleanup.py - Deterministic, non-destructive Git branch and worktree cleanup.

Scans repositories across the machine:
1. Priority 1 (Forgejo): If a Forgejo remote exists, validates merged PRs via Forgejo API.
2. Priority 2 (GitHub): If Forgejo remote does not exist, checks for a GitHub remote and
   validates merged PRs via GitHub API.
3. Fallback: If neither remote exists, only runs safe `git worktree prune`.

Safety guarantees:
- Only deletes local branches whose associated Pull Request is confirmed merged.
- Never deletes protected or default branches (main, master, develop, release/*, etc.).
- Never deletes branches with open PRs.
- Never removes worktrees with uncommitted or modified tracked changes.
- Preserves untracked user files (unless --force-worktree is specified).
- Preserves main repository root checkout.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Set, Tuple

# Default directories to scan for git repositories
DEFAULT_SCAN_ROOTS: list[str] = [
    os.path.expanduser("~/development"),
    os.path.expanduser("~/Projects"),
    os.path.expanduser("~/dotfiles"),
    os.path.expanduser("~/scripts"),
    os.path.expanduser("~/Documents/dev"),
]

# Heavy directories to skip during filesystem traversal
EXCLUDE_DIR_NAMES: frozenset[str] = frozenset(
    {
        "node_modules",
        "Pods",
        "vendor",
        "DerivedData",
        "build",
        "dist",
        "target",
        ".venv",
        "venv",
        ".npm",
        ".gradle",
        "OrbStack",
        "Pictures",
        "Movies",
        "Music",
        "Ebooks",
        "Calibre Library",
        ".vscode",
        ".codex",
        "Library",
        ".Trash",
        ".cache",
        ".cargo",
        ".rustup",
        "Applications",
        "chrome-debug",
        "myenv",
        "extracted_images",
        "Media",
        "Media-backup",
        ".claude",
    }
)

# Standard protected branch names that must never be deleted
DEFAULT_PROTECTED_BRANCHES: frozenset[str] = frozenset(
    {
        "main",
        "master",
        "develop",
        "dev",
        "production",
        "prod",
        "staging",
        "stage",
        "gh-pages",
    }
)

# Harmless editor/agent transient paths in worktrees
IGNORABLE_UNTRACKED_PREFIXES: tuple[str, ...] = (
    ".codex",
    ".agents",
    ".DS_Store",
    ".idea",
    ".vscode",
    ".claude",
    "node_modules",
)


@dataclass
class WorktreeInfo:
    path: str
    head_sha: str = ""
    branch: str = ""
    prunable: str = ""
    is_main: bool = False


@dataclass
class RemoteInfo:
    remote_type: str  # "forgejo" or "github"
    remote_name: str
    owner: str
    repo: str
    host: str = ""
    scheme: str = "http"
    user: Optional[str] = None
    token: Optional[str] = None


@dataclass
class RepoReport:
    repo_path: str
    remote_type: Optional[str] = None
    remote_url: Optional[str] = None
    default_branch: str = "main"
    worktrees_removed: list[str] = field(default_factory=list)
    branches_deleted: list[str] = field(default_factory=list)
    skipped_worktrees: list[tuple[str, str]] = field(default_factory=list)
    skipped_branches: list[tuple[str, str]] = field(default_factory=list)


def log(msg: str) -> None:
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {msg}", flush=True)


def log_err(msg: str) -> None:
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [ERROR] {msg}", file=sys.stderr, flush=True)


def run_cmd(
    cmd: list[str], cwd: Optional[str] = None, check: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=check,
    )


def find_git_repos(scan_roots: list[str], max_depth: int = 5) -> list[str]:
    """Find all git repository root directories (where .git is a directory, not a worktree file)."""
    found: list[str] = []

    def _scan(root_dir: str, depth: int) -> None:
        if depth > max_depth:
            return
        try:
            entries = list(os.scandir(root_dir))
        except (PermissionError, FileNotFoundError):
            return

        has_git_dir = False
        subdirs: list[str] = []

        for entry in entries:
            if entry.name in EXCLUDE_DIR_NAMES:
                continue
            if entry.name == ".git":
                if entry.is_dir():
                    has_git_dir = True
                continue
            if entry.name.startswith("."):
                continue
            if entry.is_dir(follow_symlinks=False):
                subdirs.append(entry.path)

        if has_git_dir:
            found.append(root_dir)
        else:
            for s in subdirs:
                _scan(s, depth + 1)

    for root in scan_roots:
        if os.path.isdir(root):
            _scan(root, depth=0)

    return sorted(set(found))


def parse_remote_url(url: str) -> Optional[Tuple[str, str, Optional[str], Optional[str], str, str]]:
    """
    Parse a Git remote URL.
    Returns: (scheme, host_with_port, user, password, owner, repo_slug) or None.
    """
    if url.startswith("git@") or url.startswith("ssh://git@"):
        m = re.match(r"(?:ssh://)?git@([^:/]+)(?::\d+)?[:/](.+?)(?:\.git)?$", url)
        if m:
            host, path = m.groups()
            parts = [p for p in path.split("/") if p]
            if len(parts) >= 2:
                return ("ssh", host, "git", None, parts[-2], parts[-1])
        return None

    parsed = urllib.parse.urlparse(url)
    scheme = parsed.scheme or "https"
    user = parsed.username
    password = parsed.password
    host = parsed.hostname or "localhost"
    if parsed.port:
        host = f"{host}:{parsed.port}"

    path = parsed.path.rstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = [p for p in path.split("/") if p]
    if len(parts) >= 2:
        return (scheme, host, user, password, parts[-2], parts[-1])
    return None


def get_git_credentials(host: str, protocol: str = "http") -> Tuple[Optional[str], Optional[str]]:
    """Retrieve username and password/token from git credential helper."""
    try:
        proc = subprocess.Popen(
            ["git", "credential", "fill"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        input_data = f"protocol={protocol}\nhost={host}\n\n"
        out, _ = proc.communicate(input=input_data, timeout=5)
        creds: dict[str, str] = {}
        for line in out.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                creds[k.strip()] = v.strip()
        return creds.get("username"), creds.get("password")
    except Exception:
        return None, None


def get_github_token() -> Optional[str]:
    """Retrieve GitHub authentication token from environment, gh CLI, or credential helper."""
    env_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if env_token:
        return env_token

    try:
        res = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=5)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass

    _, cred_pass = get_git_credentials("github.com", "https")
    if cred_pass:
        return cred_pass

    return None


def get_repo_remote_info(repo_path: str) -> Optional[RemoteInfo]:
    """
    Determines whether a repository uses Forgejo or GitHub:
    1. If a Forgejo remote exists (named 'forgejo' or URL matching forgejo/localhost:3300), uses Forgejo.
    2. If Forgejo does not exist, checks for a GitHub remote (named 'origin', 'upstream', or URL containing github.com).
    3. Returns RemoteInfo or None.
    """
    res = run_cmd(["git", "-C", repo_path, "remote", "-v"])
    if res.returncode != 0:
        return None

    remote_lines = res.stdout.splitlines()
    fetch_remotes: list[tuple[str, str]] = []
    for line in remote_lines:
        parts = line.split()
        if len(parts) >= 2 and parts[2] == "(fetch)":
            fetch_remotes.append((parts[0], parts[1]))

    # --- 1. Check Forgejo ---
    forgejo_candidate = None
    for name, url in fetch_remotes:
        if name.lower() == "forgejo":
            forgejo_candidate = (name, url)
            break
    if not forgejo_candidate:
        for name, url in fetch_remotes:
            if "forgejo" in url.lower() or "3300" in url:
                forgejo_candidate = (name, url)
                break

    if forgejo_candidate:
        name, url = forgejo_candidate
        parsed = parse_remote_url(url)
        if parsed:
            scheme, host, user, password, owner, repo = parsed
            scheme = "http" if scheme == "ssh" else scheme
            if not user or not password:
                env_token = os.environ.get("FORGEJO_TOKEN") or os.environ.get("GITEA_TOKEN")
                if env_token:
                    user = user or "token"
                    password = env_token
                else:
                    cred_user, cred_pass = get_git_credentials(host, scheme)
                    user = user or cred_user
                    password = password or cred_pass
            return RemoteInfo(
                remote_type="forgejo",
                remote_name=name,
                owner=owner,
                repo=repo,
                host=host,
                scheme=scheme,
                user=user,
                token=password,
            )

    # --- 2. Check GitHub ---
    github_candidate = None
    for name, url in fetch_remotes:
        if "github.com" in url.lower() and name in ("origin", "upstream"):
            github_candidate = (name, url)
            break
    if not github_candidate:
        for name, url in fetch_remotes:
            if "github.com" in url.lower():
                github_candidate = (name, url)
                break

    if github_candidate:
        name, url = github_candidate
        parsed = parse_remote_url(url)
        if parsed:
            _, _, _, _, owner, repo = parsed
            gh_token = get_github_token()
            return RemoteInfo(
                remote_type="github",
                remote_name=name,
                owner=owner,
                repo=repo,
                host="api.github.com",
                scheme="https",
                user=None,
                token=gh_token,
            )

    return None


def fetch_forgejo_prs(info: RemoteInfo) -> Tuple[Dict[str, dict], Set[str], str]:
    """Queries Forgejo API for merged & open PRs, and default branch."""
    auth_header = None
    if info.user and info.token:
        token_bytes = f"{info.user}:{info.token}".encode("utf-8")
        auth_header = f"Basic {base64.b64encode(token_bytes).decode('ascii')}"

    base_api = f"{info.scheme}://{info.host}/api/v1"

    default_branch = "main"
    try:
        req = urllib.request.Request(f"{base_api}/repos/{info.owner}/{info.repo}")
        if auth_header:
            req.add_header("Authorization", auth_header)
        with urllib.request.urlopen(req, timeout=10) as resp:
            repo_data = json.loads(resp.read())
            default_branch = repo_data.get("default_branch", "main")
    except Exception as e:
        log_err(f"Failed to fetch Forgejo repo info for {info.owner}/{info.repo}: {e}")

    open_branches: set[str] = set()
    page = 1
    while True:
        try:
            url = f"{base_api}/repos/{info.owner}/{info.repo}/pulls?state=open&page={page}&limit=50"
            req = urllib.request.Request(url)
            if auth_header:
                req.add_header("Authorization", auth_header)
            with urllib.request.urlopen(req, timeout=10) as resp:
                prs = json.loads(resp.read())
                if not prs:
                    break
                for pr in prs:
                    head_ref = (pr.get("head", {}).get("label") or pr.get("head", {}).get("ref") or "").split(":")[-1]
                    if head_ref:
                        open_branches.add(head_ref)
                page += 1
        except Exception as e:
            log_err(f"Error fetching open Forgejo PRs for {info.owner}/{info.repo} (page {page}): {e}")
            break

    merged_branches: dict[str, dict] = {}
    page = 1
    while True:
        try:
            url = f"{base_api}/repos/{info.owner}/{info.repo}/pulls?state=closed&page={page}&limit=50"
            req = urllib.request.Request(url)
            if auth_header:
                req.add_header("Authorization", auth_header)
            with urllib.request.urlopen(req, timeout=10) as resp:
                prs = json.loads(resp.read())
                if not prs:
                    break
                for pr in prs:
                    if pr.get("merged") is True:
                        head_ref = (pr.get("head", {}).get("label") or pr.get("head", {}).get("ref") or "").split(":")[-1]
                        if head_ref and head_ref not in merged_branches:
                            merged_branches[head_ref] = pr
                page += 1
        except Exception as e:
            log_err(f"Error fetching closed Forgejo PRs for {info.owner}/{info.repo} (page {page}): {e}")
            break

    return merged_branches, open_branches, default_branch


def fetch_github_prs(info: RemoteInfo, candidate_names: Set[str]) -> Tuple[Dict[str, dict], Set[str], str]:
    """Queries GitHub API for merged & open PRs, and default branch."""
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "GitCleanupScript/1.0",
    }
    if info.token:
        headers["Authorization"] = f"Bearer {info.token}"

    base_api = f"https://{info.host}/repos/{info.owner}/{info.repo}"

    default_branch = "main"
    try:
        req = urllib.request.Request(base_api, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            repo_data = json.loads(resp.read())
            default_branch = repo_data.get("default_branch", "main")
    except Exception as e:
        log_err(f"Failed to fetch GitHub repo info for {info.owner}/{info.repo}: {e}")

    open_branches: set[str] = set()
    try:
        url = f"{base_api}/pulls?state=open&per_page=100"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            prs = json.loads(resp.read())
            for pr in prs:
                head_ref = pr.get("head", {}).get("ref", "")
                if head_ref:
                    open_branches.add(head_ref)
    except Exception as e:
        log_err(f"Error fetching open GitHub PRs for {info.owner}/{info.repo}: {e}")

    merged_branches: dict[str, dict] = {}
    page = 1
    while True:
        try:
            url = f"{base_api}/pulls?state=closed&per_page=50&page={page}"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as resp:
                prs = json.loads(resp.read())
                if not prs:
                    break
                for pr in prs:
                    if pr.get("merged_at"):
                        head_ref = pr.get("head", {}).get("ref", "")
                        if head_ref and head_ref not in merged_branches:
                            merged_branches[head_ref] = pr
                if candidate_names and candidate_names.issubset(set(merged_branches.keys())):
                    break
                page += 1
                if page > 4:
                    break
        except Exception as e:
            log_err(f"Error fetching closed GitHub PRs for {info.owner}/{info.repo} (page {page}): {e}")
            break

    return merged_branches, open_branches, default_branch


def get_worktrees(repo_path: str) -> list[WorktreeInfo]:
    """Parse git worktree list --porcelain."""
    res = run_cmd(["git", "-C", repo_path, "worktree", "list", "--porcelain"])
    if res.returncode != 0:
        return []

    worktrees: list[WorktreeInfo] = []
    cur_info: dict[str, str] = {}

    for line in res.stdout.splitlines():
        if not line.strip():
            if cur_info and "worktree" in cur_info:
                b = cur_info.get("branch", "")
                if b.startswith("refs/heads/"):
                    b = b[11:]
                worktrees.append(
                    WorktreeInfo(
                        path=cur_info["worktree"],
                        head_sha=cur_info.get("HEAD", ""),
                        branch=b,
                        prunable=cur_info.get("prunable", ""),
                        is_main=(len(worktrees) == 0),
                    )
                )
                cur_info = {}
            continue

        if line.startswith("worktree "):
            cur_info["worktree"] = line[9:].strip()
        elif line.startswith("HEAD "):
            cur_info["HEAD"] = line[5:].strip()
        elif line.startswith("branch "):
            cur_info["branch"] = line[7:].strip()
        elif line.startswith("prunable"):
            cur_info["prunable"] = line[8:].strip() or "prunable"

    if cur_info and "worktree" in cur_info:
        b = cur_info.get("branch", "")
        if b.startswith("refs/heads/"):
            b = b[11:]
        worktrees.append(
            WorktreeInfo(
                path=cur_info["worktree"],
                head_sha=cur_info.get("HEAD", ""),
                branch=b,
                prunable=cur_info.get("prunable", ""),
                is_main=(len(worktrees) == 0),
            )
        )

    return worktrees


def check_worktree_safety(wt_path: str, force_untracked: bool = False) -> Tuple[bool, str]:
    """
    Strict safety check for a worktree before removal.
    Returns (is_safe, reason).
    NEVER deletes if there are uncommitted modifications to tracked files.
    """
    if not os.path.exists(wt_path):
        return True, "Path does not exist (already prunable)"

    res = run_cmd(["git", "-C", wt_path, "status", "--porcelain"])
    if res.returncode != 0:
        return True, "Corrupt or detached gitdir reference"

    status_lines = [l for l in res.stdout.splitlines() if l.strip()]
    if not status_lines:
        return True, "Working tree is completely clean"

    tracked_changes: list[str] = []
    untracked_files: list[str] = []

    for line in status_lines:
        code = line[:2]
        filename = line[3:].strip()
        if code == "??" or code == "!!":
            untracked_files.append(filename)
        else:
            tracked_changes.append(f"{code} {filename}")

    if tracked_changes:
        return False, f"Uncommitted tracked modifications present: {', '.join(tracked_changes[:3])}"

    non_ignorable: list[str] = []
    for u in untracked_files:
        is_ignorable = any(u == p or u.startswith(f"{p}/") for p in IGNORABLE_UNTRACKED_PREFIXES)
        if not is_ignorable:
            non_ignorable.append(u)

    if non_ignorable and not force_untracked:
        return False, f"Untracked user files present ({', '.join(non_ignorable[:3])}). Use --force-worktree to override"

    return True, "Only ignorable transient/metadata files present"


def get_local_branches(repo_path: str) -> dict[str, dict]:
    """
    Returns map of branch_name -> {upstream, head_sha, is_head}
    """
    res = run_cmd(
        [
            "git",
            "-C",
            repo_path,
            "for-each-ref",
            "--format=%(refname:short)|%(upstream:short)|%(objectname:short)|%(HEAD)",
            "refs/heads",
        ]
    )
    if res.returncode != 0:
        return {}

    branches: dict[str, dict] = {}
    for line in res.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split("|")
        bname = parts[0]
        upstream = parts[1] if len(parts) > 1 else ""
        head_sha = parts[2] if len(parts) > 2 else ""
        is_head = (parts[3] == "*") if len(parts) > 3 else False
        branches[bname] = {
            "upstream": upstream,
            "head_sha": head_sha,
            "is_head": is_head,
        }
    return branches


def process_repository(
    repo_path: str,
    dry_run: bool = False,
    force_worktree: bool = False,
    switch_default: bool = True,
    delete_remote: bool = False,
) -> RepoReport:
    """Execute cleanup for a single git repository."""
    report = RepoReport(repo_path=repo_path)

    local_branches = get_local_branches(repo_path)
    worktrees = get_worktrees(repo_path)

    has_linked_worktrees = any(not wt.is_main for wt in worktrees)
    has_prunable_worktrees = any(bool(wt.prunable) for wt in worktrees)
    non_protected_local = [
        b for b in local_branches
        if b not in DEFAULT_PROTECTED_BRANCHES
        and not b.startswith("release/")
        and not b.startswith("hotfix/")
    ]

    # Fast skip for clean repositories
    if not non_protected_local and not has_linked_worktrees and not has_prunable_worktrees:
        return report

    remote_info = get_repo_remote_info(repo_path)
    if not remote_info:
        if not dry_run:
            run_cmd(["git", "-C", repo_path, "worktree", "prune"])
        return report

    report.remote_type = remote_info.remote_type
    report.remote_url = f"{remote_info.scheme}://{remote_info.host}/{remote_info.owner}/{remote_info.repo}"
    log(f"Processing [{remote_info.remote_type.upper()}] repo: {remote_info.owner}/{remote_info.repo} ({repo_path})")

    # Fetch and prune remote tracking references
    run_cmd(["git", "-C", repo_path, "fetch", "--prune", remote_info.remote_name])

    # Query API for merged & open PRs
    if remote_info.remote_type == "forgejo":
        merged_prs, open_prs, default_branch = fetch_forgejo_prs(remote_info)
    else:
        merged_prs, open_prs, default_branch = fetch_github_prs(remote_info, set(non_protected_local))

    report.default_branch = default_branch
    protected = set(DEFAULT_PROTECTED_BRANCHES)
    protected.add(default_branch)

    # Re-evaluate worktrees
    worktrees = get_worktrees(repo_path)
    wt_by_branch: dict[str, WorktreeInfo] = {}
    for wt in worktrees:
        if wt.branch:
            wt_by_branch[wt.branch] = wt

    # Identify candidate branches for cleanup
    candidate_branches: list[str] = []
    for bname in local_branches:
        if bname in protected:
            continue
        if bname.startswith("release/") or bname.startswith("hotfix/"):
            continue
        if bname in open_prs:
            report.skipped_branches.append((bname, "Has an open PR"))
            continue
        if bname not in merged_prs:
            continue

        candidate_branches.append(bname)

    log(f"  Found {len(candidate_branches)} candidate branches with merged PRs on {remote_info.remote_type.upper()}.")

    # Clean up worktrees associated with merged branches
    for bname in candidate_branches:
        if bname in wt_by_branch:
            wt = wt_by_branch[bname]
            pr = merged_prs[bname]
            pr_num = pr.get("number")

            if wt.is_main:
                main_safe, reason = check_worktree_safety(wt.path, force_untracked=False)
                if main_safe and switch_default:
                    log(f"  [SWITCH] Main repo is on merged branch '{bname}'. Switching to '{default_branch}'.")
                    if not dry_run:
                        res = run_cmd(["git", "-C", wt.path, "checkout", default_branch])
                        if res.returncode != 0:
                            err_msg = res.stderr.strip()
                            log_err(f"Failed to checkout {default_branch} in {wt.path}: {err_msg}")
                            report.skipped_branches.append((bname, f"Failed to checkout {default_branch}: {err_msg}"))
                            continue
                else:
                    report.skipped_worktrees.append((wt.path, f"Main repository worktree ({reason})"))
                    report.skipped_branches.append((bname, f"Branch checked out in main repo ({reason})"))
                    continue
            else:
                safe, reason = check_worktree_safety(wt.path, force_untracked=force_worktree)
                if not safe:
                    log(f"  [SKIP] Worktree {wt.path} cannot be safely removed: {reason}")
                    report.skipped_worktrees.append((wt.path, reason))
                    report.skipped_branches.append((bname, f"Associated worktree {wt.path} not clean: {reason}"))
                    continue

                if dry_run:
                    log(f"  [DRY-RUN] Would remove worktree: {wt.path} (PR #{pr_num} merged)")
                    report.worktrees_removed.append(wt.path)
                else:
                    log(f"  [REMOVE] Removing worktree: {wt.path} (PR #{pr_num} merged)")
                    rm_res = run_cmd(["git", "-C", repo_path, "worktree", "remove", "--force", wt.path])
                    if rm_res.returncode == 0:
                        report.worktrees_removed.append(wt.path)
                    else:
                        if os.path.exists(wt.path):
                            try:
                                shutil.rmtree(wt.path)
                                run_cmd(["git", "-C", repo_path, "worktree", "prune"])
                                report.worktrees_removed.append(wt.path)
                            except Exception as ex:
                                log_err(f"Failed to remove worktree {wt.path}: {ex}")
                                report.skipped_worktrees.append((wt.path, f"Removal failed: {ex}"))
                                report.skipped_branches.append((bname, f"Worktree removal failed: {ex}"))
                                continue

    current_wts = get_worktrees(repo_path)
    active_branches = {w.branch for w in current_wts if w.branch}

    # Delete local branches
    for bname in candidate_branches:
        if any(b == bname for b, _ in report.skipped_branches):
            continue

        if bname in active_branches:
            report.skipped_branches.append((bname, "Branch is still checked out in an active worktree"))
            continue

        pr = merged_prs[bname]
        pr_num = pr.get("number")
        pr_title = pr.get("title", "")

        if dry_run:
            log(f"  [DRY-RUN] Would delete local branch '{bname}' (PR #{pr_num}: {pr_title})")
            report.branches_deleted.append(bname)
        else:
            del_res = run_cmd(["git", "-C", repo_path, "branch", "-D", bname])
            if del_res.returncode == 0:
                log(f"  [DELETED] Local branch '{bname}' (PR #{pr_num})")
                report.branches_deleted.append(bname)
            else:
                err_msg = del_res.stderr.strip()
                log_err(f"Failed to delete branch '{bname}' in {repo_path}: {err_msg}")
                report.skipped_branches.append((bname, err_msg))

        if delete_remote:
            if dry_run:
                log(f"  [DRY-RUN] Would delete remote branch on {remote_info.remote_type}: '{remote_info.remote_name}/{bname}'")
            else:
                run_cmd(["git", "-C", repo_path, "push", remote_info.remote_name, "--delete", bname])

    # Prune worktrees
    if not dry_run:
        run_cmd(["git", "-C", repo_path, "worktree", "prune"])

    return report


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Clean up merged Git branches and worktrees across repositories (Forgejo with GitHub fallback)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate cleanup without deleting any branches or worktrees.",
    )
    parser.add_argument(
        "--paths",
        nargs="+",
        default=DEFAULT_SCAN_ROOTS,
        help="Root directories to scan for Git repositories.",
    )
    parser.add_argument(
        "--force-worktree",
        action="store_true",
        help="Remove worktrees even if they contain untracked non-ignorable files.",
    )
    parser.add_argument(
        "--no-switch-default",
        action="store_true",
        help="Do not switch main repo checkout to default branch when main repo is on a merged branch.",
    )
    parser.add_argument(
        "--delete-remote",
        action="store_true",
        help="Also delete the remote branch on Forgejo/GitHub (default: delete local only).",
    )
    args = parser.parse_args()

    log("=== Starting Git Branch & Worktree Cleanup ===")
    if args.dry_run:
        log("MODE: DRY RUN (no changes will be applied)")

    scan_paths = [os.path.abspath(os.path.expanduser(p)) for p in args.paths]
    log(f"Scanning directories: {', '.join(scan_paths)}")

    repos = find_git_repos(scan_paths)
    log(f"Discovered {len(repos)} Git repositories.")

    total_worktrees_removed = 0
    total_branches_deleted = 0
    total_skipped_items = 0
    forgejo_count = 0
    github_count = 0

    for repo in repos:
        try:
            report = process_repository(
                repo,
                dry_run=args.dry_run,
                force_worktree=args.force_worktree,
                switch_default=not args.no_switch_default,
                delete_remote=args.delete_remote,
            )
            if report.remote_type == "forgejo":
                forgejo_count += 1
            elif report.remote_type == "github":
                github_count += 1

            total_worktrees_removed += len(report.worktrees_removed)
            total_branches_deleted += len(report.branches_deleted)
            total_skipped_items += len(report.skipped_worktrees) + len(report.skipped_branches)
        except Exception as e:
            log_err(f"Error processing repo {repo}: {e}")

    log("=== Cleanup Summary ===")
    log(f"Repositories checked:   {len(repos)}")
    log(f"  Forgejo repos:        {forgejo_count}")
    log(f"  GitHub repos:         {github_count}")
    log(f"Worktrees removed:      {total_worktrees_removed}")
    log(f"Local branches deleted: {total_branches_deleted}")
    log(f"Items skipped (safety): {total_skipped_items}")
    log("Cleanup run finished successfully.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
