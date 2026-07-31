# App Store screenshot generators

Run these scripts from the repository root on macOS. The source directory must
contain the captured screenshots referenced by the selected script.

```sh
swift scripts/generate_appstore_zh.swift \
  --source-dir /path/to/zh-captures \
  --background-dir /path/to/backgrounds

swift scripts/generate_appstore_en.swift \
  --source-dir /path/to/en-captures \
  --background-dir /path/to/backgrounds
```

By default, generated files are written under `AppStoreAssets/`. Use
`--output-dir` to choose another destination and `--app-icon` to override the
repository app icon.
