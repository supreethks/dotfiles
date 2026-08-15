# Desktop verification (ViMark)

Use this when a change touches the palette UI, window sizing, focus/blur, or capture → add-bookmark flow.

## Run the app

```bash
npm run tauri dev
```

Global toggle is typically `⌘⇧Space`. Confirm the panel shows, focuses, and accepts keyboard input (macOS often needs app activation, not only `set_focus`).

## Checklist by change type

| Change | Exercise |
|---|---|
| Search / list / selection | Type a query, clear it, navigate with `⌃J`/`⌃K` or arrows, open with Enter |
| Window height | Empty library, no-results, 1–3 recents, many results; confirm no clipped footer/search bar and no stuck short (≈120px) or oddly narrow width |
| Mode stack | Add bookmark (`⌘⇧S`), edit, import; Escape pops a layer without killing the stack; toggle hide/show preserves modal state |
| Focus loss | In search mode, click another app — palette should hide. In add/edit/import, it must stay open |
| Capture | Trigger pending bookmark (extension / native host); dialog must surface at dialog height, not compact search height |
| Drafts | Abandon a capture, confirm unsaved pill + `⌘D` resume |

## Tauri MCP

When `user-@hypothesi/tauri-mcp-server` is available:

1. `driver_session` / ensure the app is running
2. `webview_screenshot` + `webview_dom_snapshot` for each state
3. `webview_execute_js` only for readouts; prefer real keyboard/UI for behavioural claims
4. `ipc_execute_command` to inspect backend state when the bug is command-side

## Screenshots

Keep one screenshot per meaningful state in the PR notes or chat. Prefer the actual webview bounds over a full desktop capture so width/height regressions are obvious.
