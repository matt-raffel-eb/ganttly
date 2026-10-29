# Architecture

One rule shapes the app: **the project is the single source of truth, and everything on screen is computed from it.** The grid and the chart are two views of the same data, so they can't disagree.

```
 user edit ──► ProjectController ──► Project (immutable) ──► computeSchedule() ──► Schedule
                   │  undo/redo                                                    │
                   └──────────── notifyListeners ──► grid + chart + summary ◄──────┘
```

## Layers (`src/lib/`)

| Folder | Role | Depends on |
|---|---|---|
| `model/` | `Project`, `Task`, `Dependency`: what the user entered. Immutable; dates are UTC midnight. `sample_project.dart` loads the start-up example, a bundled `.ganttly` file (`src/assets/samples/`). | nothing |
| `engine/` | `WorkCalendar` (working-day maths, like Excel's WORKDAY/NETWORKDAYS) and `computeSchedule()` (every task's start and finish). Pure Dart, no Flutter. | `model` |
| `io/` | `ProjectFile`: the `.ganttly` JSON format, versioned. `AppSettings`: a small `settings.json` per user (the last project, reopened on start-up by `startup.dart`). | `model` |
| `state/` | `ProjectController` (`ChangeNotifier`): the open project, the computed schedule, selection, undo/redo (whole-project snapshots, up to 200), unsaved-changes flag, and the edit operations (add, delete, indent, move…). | `model`, `engine` |
| `ui/` | The window (`home_page.dart`), the task grid, the chart painters, PNG export, file dialogs, project settings. | all of the above |

## Scheduling rules (`engine/scheduler.dart`)

- Finish-to-start links only, with an optional lag in working days (negative overlaps).
- A leaf task starts on the first working day allowed by the project start, its own pinned start ("start no earlier than"), every summary above it, and its predecessors. It lasts its duration in working days.
- A milestone (duration 0) after other work sits on that work's last day, and its successors start the next working day. A free-standing milestone marks the start of its day.
- A summary spans the tasks under it. Its own links and pinned start hold back every task under it.
- Circular, self and unknown links are reported on the task (red outline, an icon in the grid, a count in the summary bar) and otherwise ignored, so one bad link never blanks the chart.

The whole schedule is recomputed after every edit. That's simple and plenty fast for hundreds of tasks; make it incremental only if profiling says so.

## The chart

`ui/gantt/gantt_painter.dart` holds `GanttLayout` (sizes, date range, zoom) and two `CustomPainter`s: the date header and the rows. The screen and the PNG export use the same painters, so the export always matches what you see. The export (`png_export.dart`) records the full chart, not just the visible part, plus a title and a task table, into a picture and encodes it as PNG.

On screen, the date header is pinned and follows the chart sideways. The rows scroll both ways, with both scrollbars always shown at the window's edges. The grid and the chart scroll up and down together (scroll controllers kept in step). The scroll views don't handle two things on their own, so a `Listener` does: the wheel over the header scrolls sideways, and ⌘/Ctrl + wheel zooms around the pointer. Zoom is the width of a day in pixels (22 = 100%, 4 to 64).

## Packages

Only `file_selector` (official, from the Flutter team) for the open and save dialogs. Keep it that way unless a feature clearly needs more.

## Platform notes

- macOS: minimum 12.0. The App Sandbox is **off**, so the app can reopen the last project after a restart (a sandboxed app may only read a file in the session the user picked it, unless it stores security-scoped bookmarks). A Mac App Store release would need the sandbox back on, plus bookmarks.
- Settings live in `~/Library/Application Support/Ganttly/settings.json` (macOS), `%APPDATA%\Ganttly` (Windows) or `~/.config/ganttly` (Linux).
- macOS release builds are **Apple Silicon (arm64) only** for now: `ARCHS = arm64` in the project's Release and Profile settings (`src/macos/Runner.xcodeproj`). Flutter 3.44 checks the framework with `lipo -verify_arch arm64 x86_64`, and Xcode 27's `lipo` accepts only one architecture there, so a universal build fails ("does not contain architectures"). Remove the two `ARCHS = arm64` lines once Flutter fixes this, to get Intel support back. Debug builds were never affected (they build for this Mac only).
- Window: 1440 × 860 by default (macOS, Windows, Linux runners).
