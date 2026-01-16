#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path
import sys

def extract_zip(zip_path, extract_to):
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to)

def merge_json_lists(file_name, export_dirs, merged_dir):
    merged = {}
    for d in export_dirs:
        path = Path(d) / file_name
        if path.exists():
            with open(path, "r", encoding="utf-8") as f:
                try:
                    data = json.load(f)
                except json.JSONDecodeError:
                    continue
                for entry in data:
                    merged[entry["id"]] = entry
    if merged:
        with open(merged_dir / file_name, "w", encoding="utf-8") as f:
            json.dump(list(merged.values()), f, indent=2, ensure_ascii=False)

def merge_messages(export_dirs, merged_dir):
    for d in export_dirs:
        print(d, file=sys.stderr)
        for path in Path(d).rglob("*.json"):
            rel_path = path.relative_to(d)
            target = merged_dir / rel_path
            target.parent.mkdir(parents=True, exist_ok=True)

            if target.exists():
                try:
                    with open(target, "r", encoding="utf-8") as f1, open(path, "r", encoding="utf-8") as f2:
                        data1 = json.load(f1)
                        data2 = json.load(f2)
                    merged_msgs = {m["ts"]: m for m in data1 + data2}.values()
                    with open(target, "w", encoding="utf-8") as f:
                        json.dump(sorted(merged_msgs, key=lambda x: x["ts"]), f, indent=2, ensure_ascii=False)
                except json.JSONDecodeError:
                    pass
                except KeyError:
                    print(f"KeyError: {path} is skipped", file=sys.stderr)
                    pass
                except TypeError:
                    print(f"TypeError: {path} is skipped", file=sys.stderr)
                    pass
            else:
                shutil.copy2(path, target)

def zip_directory(folder_path, output_path):
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(folder_path):
            for file in files:
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, folder_path)
                zipf.write(abs_path, rel_path)

def main():
    parser = argparse.ArgumentParser(description="Merge multiple Slack export ZIPs into one unified export.")
    parser.add_argument("zips", nargs="+", help="Slack export ZIP files to merge")
    parser.add_argument("-o", "--output", default="output.zip", help="Output ZIP file name (default: output.zip)")
    args = parser.parse_args()

    output_path = Path(args.output)
    if output_path.exists():
        print(f"Error: Output file '{output_path}' already exists. Aborting to avoid overwrite.")
        return

    with tempfile.TemporaryDirectory() as tmpdir:
        extracted_dirs = []
        for i, zip_file in enumerate(args.zips):
            print(zip_file, file=sys.stderr)
            dir_path = Path(tmpdir) / f"export_{i}"
            extract_zip(zip_file, dir_path)
            extracted_dirs.append(dir_path)

        merged_dir = Path(tmpdir) / "merged"
        merged_dir.mkdir(exist_ok=True)

        # merge users.json & channels.json
        merge_json_lists("users.json", extracted_dirs, merged_dir)
        merge_json_lists("channels.json", extracted_dirs, merged_dir)

        # merge message files
        merge_messages(extracted_dirs, merged_dir)

        # zip merged directory
        zip_directory(merged_dir, output_path)
        print(f"Merged export created: {output_path}")

if __name__ == "__main__":
    main()
