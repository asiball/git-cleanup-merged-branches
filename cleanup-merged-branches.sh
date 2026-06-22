#!/usr/bin/env bash
#
# cleanup-merged-branches.sh
#
# リモートのマージ済みブランチを検出し、必要なら削除する汎用スクリプト。
#
# マージ済み判定は次のいずれかを満たすもの:
#   1. tip がベースの祖先 (通常マージ / fast-forward)        -- git merge-base --is-ancestor
#   2. squash / rebase マージ済み (パッチがベースに存在する)  -- git cherry ヒューリスティック
#   3. 対応する PR が GitHub 上で merged 状態 (gh があれば)    -- gh pr view
#
# 使い方:
#   ./cleanup-merged-branches.sh                  # ドライラン (判定して一覧表示のみ)
#   ./cleanup-merged-branches.sh --delete         # マージ済みブランチを実際に削除
#   ./cleanup-merged-branches.sh --no-gh          # GitHub 照合を使わず git のみで判定
#   ./cleanup-merged-branches.sh --remote upstream  # 対象リモートを指定 (既定: origin)
#   ./cleanup-merged-branches.sh --base develop     # ベースブランチを指定 (既定: 自動検出)
#
set -euo pipefail

REMOTE="origin"
BASE=""          # 空なら自動検出
DO_DELETE=0
USE_GH=1

while [ $# -gt 0 ]; do
  case "$1" in
    --delete)  DO_DELETE=1 ;;
    --no-gh)   USE_GH=0 ;;
    --remote)  REMOTE="${2:?--remote にはリモート名が必要}"; shift ;;
    --base)    BASE="${2:?--base にはブランチ名が必要}"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "不明な引数: $1" >&2; exit 2 ;;
  esac
  shift
done

# 保護するブランチ (削除対象から除外)
PROTECTED="^(main|master|HEAD|develop)$"

command -v gh >/dev/null 2>&1 || USE_GH=0

# リモートのデフォルトブランチを検出
detect_base() {
  local b
  b=$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null) \
    && { echo "${b#"$REMOTE"/}"; return; }
  b=$(git remote show "$REMOTE" 2>/dev/null | sed -n 's/.*HEAD branch: //p')
  [ -n "$b" ] && { echo "$b"; return; }
  echo "main"
}

echo "リモート最新化 (fetch --prune)..."
git fetch --prune "$REMOTE" >/dev/null 2>&1

[ -n "$BASE" ] || BASE=$(detect_base)
BASE_REF="$REMOTE/$BASE"
echo "ベースブランチ: $BASE_REF"

if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  echo "エラー: $BASE_REF が見つかりません。--base で指定してください。" >&2
  exit 1
fi

# squash / rebase マージ判定:
# ブランチの tree から merge-base を親とする仮コミットを作り、
# そのパッチが base に既に存在する (git cherry が '-') かを見る。
is_squash_merged() {
  local branch="$1" mb tree fake
  mb=$(git merge-base "$BASE_REF" "$branch") || return 1
  tree=$(git rev-parse "$branch^{tree}")
  fake=$(git commit-tree "$tree" -p "$mb" -m _)
  [ "$(git cherry "$BASE_REF" "$fake" | head -c1)" = "-" ]
}

# GitHub の PR が merged かどうか
is_pr_merged() {
  local short="$1" state
  state=$(gh pr view "$short" --json state -q .state 2>/dev/null) || return 1
  [ "$state" = "MERGED" ]
}

merged=()
unmerged=()

while read -r ref; do
  [ -n "$ref" ] || continue
  # 'origin' (HEAD symref) や 'origin/HEAD' をスキップ
  [ "$ref" = "$REMOTE" ] && continue
  short="${ref#"$REMOTE"/}"
  [ "$short" = "$BASE" ] && continue
  [[ "$short" =~ $PROTECTED ]] && continue

  reason=""
  if git merge-base --is-ancestor "$ref" "$BASE_REF" 2>/dev/null; then
    reason="ancestor"
  elif is_squash_merged "$ref"; then
    reason="squash/rebase"
  elif [ "$USE_GH" = 1 ] && is_pr_merged "$short"; then
    reason="PR merged"
  fi

  if [ -n "$reason" ]; then
    merged+=("$short")
    printf '  \033[32mMERGED\033[0m   %-45s (%s)\n' "$short" "$reason"
  else
    unmerged+=("$short")
    printf '  \033[33mopen\033[0m     %-45s\n' "$short"
  fi
done < <(git for-each-ref --format='%(refname:short)' "refs/remotes/$REMOTE")

echo
echo "マージ済み: ${#merged[@]} 件 / 未マージ: ${#unmerged[@]} 件"

if [ "${#merged[@]}" -eq 0 ]; then
  echo "削除対象はありません。"
  exit 0
fi

if [ "$DO_DELETE" -ne 1 ]; then
  echo
  echo "削除するには --delete を付けて再実行してください (ドライラン)。"
  exit 0
fi

echo
read -r -p "上記 ${#merged[@]} 件のマージ済みブランチを $REMOTE から削除します。よろしいですか? [y/N] " ans
case "$ans" in
  y|Y|yes|YES) ;;
  *) echo "中止しました。"; exit 0 ;;
esac

for b in "${merged[@]}"; do
  echo "削除: $b"
  git push "$REMOTE" --delete "$b"
done
echo "完了。"
