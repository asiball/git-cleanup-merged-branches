#!/usr/bin/env bash
#
# install.sh — cleanup-merged-branches をクローンせずに導入する。
#
#   curl -fsSL https://raw.githubusercontent.com/asiball/git-cleanup-merged-branches/main/install.sh | bash
#
# 導入先は $BIN_DIR (既定: ~/.local/bin)。PATH に無ければ警告を出す。
#
set -euo pipefail

REPO="asiball/git-cleanup-merged-branches"
SCRIPT="cleanup-merged-branches.sh"
CMD="cleanup-merged-branches"
RAW="https://raw.githubusercontent.com/$REPO/main/$SCRIPT"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$BIN_DIR"
DEST="$BIN_DIR/$CMD"

echo "ダウンロード: $RAW"
curl -fsSL "$RAW" -o "$DEST"
chmod +x "$DEST"
echo "インストール完了: $DEST"

case ":$PATH:" in
  *":$BIN_DIR:"*) echo "実行: $CMD" ;;
  *) echo "注意: $BIN_DIR が PATH にありません。PATH に追加するか、$DEST を直接実行してください。" ;;
esac
