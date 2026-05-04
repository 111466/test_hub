---
name: github-push
description: >
  Push project code to GitHub, automatically creating a new repository if one does not exist.
  Use when users need to (1) upload/push code to GitHub, (2) save code to GitHub,
  (3) create a GitHub repo and push, (4) back up code to GitHub,
  (5) user says "push to github", "save to github", "upload to github",
  file types,or tasks that trigger it.
---

# GitHub Push

Push the current project to GitHub. If the user has not provided an existing repository, automatically create one via the GitHub API and push.

## Prerequisites

- A GitHub **Personal Access Token** (classic, with `repo` scope). Fine-grained tokens need `Contents: Read and write` + `Administration: Read and write`.
- The token and repo name can be provided by the user in conversation.

## Workflow

1. **Collect info** - Ask the user for:
   - GitHub Token (required, if not previously provided in the session)
   - Repository name (required; default to the project/directory name)
   - Public or private (optional; default public)
   - Description (optional)

2. **Ensure `.gitignore`** - Before pushing, make sure a `.gitignore` exists that excludes build artifacts, engine internals, and sensitive files. For UrhoX/SCE projects:
   ```
   .build/
   dist/
   engine-docs/
   examples/
   templates/
   urhox-libs/
   schemas/
   lua-tools/
   .emmylua/
   .project/
   .agent/
   .claude/
   .cli/
   .tmp/
   logs/
   *.meta
   .luarc.json
   ```

3. **Run the script** - Execute `github_push.py` from this skill's `scripts/` directory:
   ```bash
   python3 <skill-dir>/scripts/github_push.py \
     --token <TOKEN> \
     --repo <REPO_NAME> \
     [--private] \
     [--description "desc"] \
     [--proxy http://127.0.0.1:1080]
   ```
   - `--proxy` is required in sandboxed environments with network restrictions.
   - The script auto-detects the GitHub username from the token.
   - If the repo does not exist, it creates one automatically.
   - After push, the token is cleaned from the git remote URL.

4. **Report result** - Show the user the GitHub URL on success.

## Script Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--token` | Yes | GitHub Personal Access Token |
| `--repo` | Yes | Repository name (e.g. `my-game`) |
| `--user` | No | GitHub username (auto-detected from token) |
| `--private` | No | Create as private repo (default: public) |
| `--description` | No | Repository description |
| `--branch` | No | Branch name (default: `main`) |
| `--proxy` | No | HTTP proxy URL |

## Security Notes

- The token is only used during push and is removed from the git remote URL afterward.
- Never log or echo the token in output shown to the user.
