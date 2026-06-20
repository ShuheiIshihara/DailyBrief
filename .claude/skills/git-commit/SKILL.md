---
name: git-commit
description: >
  ステージング済みのGit変更を分析し、日本語のコミットメッセージを自動生成してgit commitを実行するスキル。
  「コミット」「commit」「コミットメッセージを作って」「git commitしたい」「ステージングが終わった」
  「差分からメッセージを考えて」など、コミット操作に関わる発言があれば必ずこのスキルを使うこと。
  ユーザーがgit addの後に何か作業を依頼してきた場合も積極的にこのスキルの利用を提案すること。
---

# Git Commit Message Generator

Analyze staged changes, propose a Japanese commit message, confirm with the user, then run `git commit`.

> For a human-readable explanation of this skill in Japanese, see `references/ja-guide.md`.

## Workflow

### Step 1: Gather context

```bash
git status
git diff --staged
git log --oneline -5
```

- `git status` — current branch and staging state
- `git diff --staged` — exact content of staged changes
- `git log --oneline -5` — recent commit history for project context

If nothing is staged, tell the user and stop.

### Step 2: Understand the changes deeply

Read the diff carefully. Don't just look at file names — infer *what* changed and *why*. Pay attention to: added/removed logic, function/variable/class names, comments, config values, error handling.

### Step 3: Write a Japanese commit message

**Format:**
```
<subject line> (≤50 chars)

<body> (optional — add when the reason isn't obvious, changes span multiple purposes, or context is worth recording)
```

**Subject line rules:**
- Start with a verb: 追加、修正、削除、リファクタリング、更新、対応、改善
- Express the *purpose*, not the files touched
- Good: 「ユーザー一覧ページの検索フィルターを追加」
- Bad: 「user.pyを変更」「修正」

**Multi-file changes:** Find the single unifying theme across all files. Never list file names.
- Good: 「リクエストログ機能を実装」
- Bad: 「app.py、config.yaml、README.mdを更新」

**Body:** Use when the *why* isn't self-evident, or when explaining how multiple components fit together. Bullet points or prose are both fine.

### Step 4: Propose and confirm

Present the message and ask for approval before committing:

```
以下のコミットメッセージを提案します：

---
<subject>

<body if any>
---

このメッセージでコミットしますか？修正したい点があれば教えてください。
```

If the user requests changes, revise and re-propose.

### Step 5: Run git commit

Once approved:

```bash
git commit -m "<subject>" -m "<body>"   # body only if present
```

After committing, show the commit hash and subject line, and remind the user they can push manually.

## Notes

- Only staged changes (`git diff --staged`) are committed. Mention unstaged changes if present, but don't include them.
- Never run `git push` — that is the user's responsibility.
- The message is a proposal; if the user wants to write their own, hand it off.
