# The `.ganttly` file format

UTF-8 JSON. It stores only what the user entered; start and finish dates are worked out again when the file opens. Code: `src/lib/io/project_file.dart`.

```json
{
  "format": "ganttly",
  "version": 1,
  "name": "Website relaunch",
  "start": "2026-11-02",
  "deadline": "2026-12-18",
  "holidays": ["2026-11-26", "2026-11-27"],
  "tasks": [
    { "id": 1, "name": "Discovery", "duration": 1 },
    { "id": 2, "name": "Stakeholder interviews", "duration": 3, "level": 1, "startNoEarlierThan": "2026-11-02" },
    { "id": 3, "name": "Requirements signed off", "duration": 0, "level": 1, "dependsOn": [2] },
    { "id": 4, "name": "Design", "duration": 5, "dependsOn": [{ "id": 3, "lag": 2 }] }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `format` | yes | Always `"ganttly"`. |
| `version` | yes | Format version, now `1`. A newer version is refused with a message. |
| `name` | | Project name. |
| `start` | yes | `YYYY-MM-DD`. No task starts earlier. |
| `deadline` | | `YYYY-MM-DD`. Marked on the chart; the plan is "late" if it finishes after it. |
| `holidays` | | `YYYY-MM-DD` list. Non-working weekdays (weekends are always off). |
| `tasks` | | In display order. |
| `tasks[].id` | yes | Unique integer; links point at it. Never reused within a file. |
| `tasks[].name` | | |
| `tasks[].duration` | | Working days (default 1). `0` is a milestone. Ignored for summaries. |
| `tasks[].level` | | Outline level (default 0). A task followed by deeper tasks is a summary. |
| `tasks[].dependsOn` | | Predecessors, finish-to-start: an id, or `{ "id": n, "lag": days }`. |
| `tasks[].startNoEarlierThan` | | `YYYY-MM-DD`. A pinned earliest start. |
| `tasks[].percentComplete` | | 0–100. Drawn as a dark line inside the bar. |
| `tasks[].notes` | | Free text. |

Fields with default values are left out when saving. Unknown fields are ignored when loading.
