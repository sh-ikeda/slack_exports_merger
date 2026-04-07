# slack exports merger
Slack エクスポートで出力された zip ファイル同士をマージする。
```
$ python path/to/slack_exports_merger.py export1.zip export2.zip -o merged.zip
```

出力された zip は [slack-export-viewer](https://github.com/hfaran/slack-export-viewer) の入力として使うことができる。
```
$ slack-export-viewer -z merged.zip --no-browser --html-only -o output_dirname
```
