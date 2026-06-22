# cleanup-merged-branches

リモートのマージ済みブランチを検出し、必要なら削除する汎用シェルスクリプト。

GitHub の **squash / rebase マージ**では、ブランチのコミットがそのまま `main`
の履歴に現れないため、`git branch --merged` だけでは「マージ済み」と判定されず
取りこぼします。このスクリプトは複数の手段を組み合わせて判定します。

## 判定ロジック

ブランチが次のいずれかを満たせば「マージ済み」とみなします。

1. **通常マージ / fast-forward** — tip がベースの祖先
   (`git merge-base --is-ancestor`)
2. **squash / rebase マージ** — ブランチの diff が既にベースに取り込まれている
   (`git cherry` ヒューリスティック)
3. **PR が merged** — 対応する PR が GitHub 上で merged 状態
   (`gh` CLI が利用可能な場合のみ)

## 使い方

```bash
./cleanup-merged-branches.sh                    # ドライラン (判定して一覧表示のみ)
./cleanup-merged-branches.sh --delete           # マージ済みを実際に削除 (確認あり)
./cleanup-merged-branches.sh --no-gh            # GitHub 照合なし (git のみ)
./cleanup-merged-branches.sh --remote upstream  # 対象リモート指定 (既定: origin)
./cleanup-merged-branches.sh --base develop     # ベースブランチ指定 (既定: 自動検出)
```

## 安全策

- **デフォルトはドライラン**。`--delete` を付けない限り削除しません。
- 削除前に y/N の確認プロンプトを出します。
- `main` / `master` / `HEAD` / `develop` は保護され、削除対象になりません。
- 実行時に `git fetch --prune` でリモート追跡参照を最新化します
  (リモートで既に消えたブランチのローカル残骸も掃除されます)。

## 必要環境

- `git`
- `gh` (任意。あれば PR の merged 状態でも判定。なくても 1・2 で動作)

## ヒント

GitHub のリポジトリ設定で **"Automatically delete head branches"**
(Settings → General) を有効にすると、PR マージ時にブランチが自動削除され、
そもそもゴミが溜まりにくくなります。
