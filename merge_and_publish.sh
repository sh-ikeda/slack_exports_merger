#!/usr/bin/env bash
#
# 複数の Slack ワークスペースについて、TSV に列挙した行ごとに
#   1. slack_exports_merger.py でエクスポート zip をマージ
#   2. slack-export-viewer で HTML に変換
#   3. 既存の公開ディレクトリをバックアップしてから新しい結果を配置
# を行う。
#
# 入力 TSV の列 (タブ区切り):
#   1: キー名        (例: dbcls)      -> export/<キー名>/ 以下に配置
#   2: 表示名        (例: DBCLS)      -> data/<表示名>, export/<キー名>/<表示名>
#   3: マージ対象 zip その1 (archive/ からの相対パス)
#   4: マージ対象 zip その2 (archive/ からの相対パス)
#   5: 出力 zip 名 (省略可。省略時は slack_merged_<キー名>_<実行日 YYYYMMDD>.zip)
#
# 使い方:
#   ./merge_and_publish.sh input.tsv

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <input.tsv>" >&2
    exit 1
fi

TSV_FILE="$1"
if [[ ! -f "$TSV_FILE" ]]; then
    echo "Error: input file not found: $TSV_FILE" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGER="$SCRIPT_DIR/slack_exports_merger.py"

ARCHIVE_DIR="archive"
DATA_DIR="data"
EXPORT_DIR="export"
BACKUP_DIR="backup"
DATE="$(date +%Y%m%d)"

mkdir -p "$DATA_DIR" "$EXPORT_DIR" "$BACKUP_DIR"

while IFS=$'\t' read -r key name zip1 zip2 outname <&3 || [[ -n "${key:-}" ]]; do
    # 空行・コメント行はスキップ
    [[ -z "${key// }" || "$key" == \#* ]] && continue

    if [[ -z "$key" || -z "$name" || -z "$zip1" || -z "$zip2" ]]; then
        echo "Error: malformed row (need at least 4 columns): $key $name $zip1 $zip2" >&2
        exit 1
    fi

    if [[ -z "${outname:-}" ]]; then
        outname="slack_merged_${key}_${DATE}.zip"
    fi

    echo "=== [$key] $name ==="

    src1="$ARCHIVE_DIR/$zip1"
    src2="$ARCHIVE_DIR/$zip2"
    out_zip="$ARCHIVE_DIR/$outname"

    for f in "$src1" "$src2"; do
        if [[ ! -f "$f" ]]; then
            echo "Error: input zip not found: $f" >&2
            exit 1
        fi
    done

    echo "--- merging: $src1 + $src2 -> $out_zip"
    python3 "$MERGER" "$src1" "$src2" -o "$out_zip"

    echo "--- converting with slack-export-viewer -> $DATA_DIR/$name"
    slack-export-viewer -z "$out_zip" --no-browser --html-only -o "$DATA_DIR/$name"

    mkdir -p "$EXPORT_DIR/$key"
    if [[ -d "$EXPORT_DIR/$key/$name" ]]; then
        backup_path="$BACKUP_DIR/${name}-${DATE}"
        echo "--- backing up existing $EXPORT_DIR/$key/$name -> $backup_path"
        mv "$EXPORT_DIR/$key/$name" "$backup_path"
    fi

    echo "--- publishing $DATA_DIR/$name -> $EXPORT_DIR/$key/"
    mv "$DATA_DIR/$name" "$EXPORT_DIR/$key/"

    echo

    # 次の行のためにリセット (5列目省略時の使い回し防止)
    outname=""
done 3< "$TSV_FILE"

echo "Done."
