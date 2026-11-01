# Useful Git Commands Cheatsheet (`git_com.md`)

A quick reference guide for stashing, rolling back, inspecting history, and managing code safely in this repository.

---

## 1. Stash & Backup Commands

### Create a Safe Backup of All Changes (Tracked + Untracked)
```powershell
git stash push -u -m "backup-before-changes"
```

### View List of All Saved Stashes
```powershell
git stash list
```

### Inspect What Was Stashed (View Diff)
```powershell
git stash show -p stash@{0}
```

### Restore Stashed Changes
* **Apply and remove from stash list:**
  ```powershell
  git stash pop
  ```
* **Apply changes but keep the stash saved:**
  ```powershell
  git stash apply stash@{0}
  ```

### Delete / Clear Stashes
* **Delete a specific stash:**
  ```powershell
  git stash drop stash@{0}
  ```
* **Clear all stashes:**
  ```powershell
  git stash clear
  ```

---

## 2. Rollback & Reset Commands

### Discard All Working Directory Changes
* **Discard changes to tracked files:**
  ```powershell
  git restore .
  ```
* **Remove untracked files & directories:**
  ```powershell
  git clean -fd
  ```

### Rollback Commits
* **Undo last commit, keep changes in working directory (soft reset):**
  ```powershell
  git reset --soft HEAD~1
  ```
* **Undo last commit and discard all changes (hard reset - destructive):**
  ```powershell
  git reset --hard HEAD~1
  ```
* **Safely revert a specific commit with a new commit (non-destructive):**
  ```powershell
  git revert <commit-hash>
  ```

---

## 3. History & Inspection Commands

### Check Status
```powershell
git status
```

### View Compact Commit History
```powershell
git log --oneline -n 10
```

### View Commit History with Branch Graph
```powershell
git log --oneline --graph --decorate -n 15
```

### Check Modified Code / Diffs
* **Summary of modified files:**
  ```powershell
  git diff --stat
  ```
* **Line-by-line diff of uncommitted changes:**
  ```powershell
  git diff
  ```

---

## 4. Branching & Remote Sync

### Create a Backup Branch Before Making Big Changes
```powershell
git branch backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')
```

### Switch Branches
```powershell
git switch main
# or
git checkout main
```

### Sync with Remote Repository
* **Fetch changes from GitHub:**
  ```powershell
  git fetch origin
  ```
* **Pull latest commits into current branch:**
  ```powershell
  git pull origin main
  ```
* **Push current branch to GitHub:**
  ```powershell
  git push origin main
  ```
