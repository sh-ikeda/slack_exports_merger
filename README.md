# slack exports merger
Slack エクスポートで出力された zip ファイル同士をマージする。
```
$ python path/to/slack_exports_merger.py export1.zip export2.zip -o merged.zip
```

出力された zip は [slack-export-viewer](https://github.com/hfaran/slack-export-viewer) の入力として使うことができる。
```
$ slack-export-viewer -z merged.zip --no-browser --html-only -o output_dirname
```

## 複数ワークスペースの一括マージ・公開: merge_and_publish.sh

複数の Slack ワークスペースについて、マージ・HTML 変換・公開ディレクトリへの配置(既存分は `backup/` へ退避)までを TSV 1つで一括実行する。

入力 TSV (タブ区切り) の例:
```
dbcls	DBCLS	slack_merged_dbcls_20260401.zip	slack_dbcls_20261001.zip
togothon	Togothon	slack_merged_togothon_20260401.zip	slack_togothon_20261001.zip
```

列の意味:
1. キー名 (公開先ディレクトリ `export/<キー名>/` に使う)
2. 表示名 (`data/<表示名>`, `export/<キー名>/<表示名>` に使う)
3. マージ対象 zip その1 (`archive/` からの相対パス)
4. マージ対象 zip その2 (`archive/` からの相対パス)
5. 出力 zip 名 (省略可。省略時は `slack_merged_<キー名>_<実行日 YYYYMMDD>.zip`)

実行:
```
$ ./merge_and_publish.sh input.tsv
```

各行について、次を行う。
1. `archive/` 内の 3, 4 列目の zip を `slack_exports_merger.py` でマージし、`archive/` に出力
2. `slack-export-viewer` で `data/<表示名>` に HTML 変換
3. 既存の `export/<キー名>/<表示名>` があれば `backup/<表示名>-<実行日>` へ退避してから、`data/<表示名>` を `export/<キー名>/` に配置

`archive/`, `data/`, `export/`, `backup/` はスクリプト実行時のカレントディレクトリからの相対パス。
