# Jot

Mac 上的 sticky notes MVP（SwiftUI），目标是像 Stickies 一样轻量，同时支持：

- 自然语言：例如输入“明早七点叫外卖”会自动识别时间并生成一条 `todo`
- Notion 风格命令：`/todo`、`/checklist`、`/remind`、`/color`、`/pin`

## Run

用 SwiftPM 运行（会弹出 macOS 窗口）：

```bash
swift run
```

数据保存在 `~/Library/Application Support/Jot/notes.json`。

## Slash commands

- `/todo <时间?> <内容>` 例如：`/todo 明早七点 叫外卖`
- `/checklist <a,b,c>` 例如：`/checklist 牛奶, 鸡蛋, 面包`
- `/remind <时间?> <内容>`：尽力写入 macOS Reminders（需要以 `.app` 方式运行才更稳定）
- `/color yellow|blue|pink|green`：切换便签背景色
- `/pin`：置顶（Always on top）
