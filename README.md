# Jot

Mac 上的 sticky notes MVP（SwiftUI），目标是像 Stickies 一样轻量，同时支持：

- 自然语言：例如输入“明早七点叫外卖”会自动识别时间并生成一条 `todo`
- Notion 风格命令：`/todo`、`/note`

## Run

用 SwiftPM 运行（会弹出 macOS 窗口）：

```bash
swift run
```

数据保存在 `~/Library/Application Support/Jot/notes.json`。

