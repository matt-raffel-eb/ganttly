# Roadmap

## Done (v0.1, 2026-10-29)

- Scheduling engine: working days, holidays, finish-to-start links with lag, summaries, milestones, pinned starts, deadline, link problems reported. Tested against hand-worked dates, including a holiday week.
- Task grid editing: name, days, start (pin/unpin), predecessors; add, delete, indent, outdent, move; undo/redo; keyboard shortcuts.
- Live Gantt chart: bars that skip non-working days, summary brackets, milestones, link arrows, today line, deadline column, zoom, selection shared with the grid.
- Save / Save As / Open (`.ganttly` JSON), unsaved-changes prompt on New and Open.
- PNG export of the whole chart with a title and task table.
- Chart scrolling both ways with always-visible scrollbars; zoom (buttons, ⌘ + wheel around the pointer, Fit, 100%).
- The sample project is a bundled `.ganttly` file, loaded like any project.

## Next

1. **Ask before closing with unsaved changes** (window close button). Needs a window-close hook (e.g. the `window_manager` package or a small platform channel).
2. **Recent files and reopen the last project** on start-up, instead of always the sample.
3. **Drag in the chart:** move a bar to pin its start, drag its end to change the duration, drag from one bar to another to link them.
4. **Collapse and expand summaries** in the grid and chart.
5. **Notes and % complete** in the grid (the model and file already have them).
6. **Platform menus** (File, Edit, View) with the same shortcuts.

## Later

- Critical path highlighting and slack.
- More link types (start-to-start, finish-to-finish).
- MS Project XML (MSPDI) import and export.
- Baselines: save a snapshot and show drift against it.
- Resources and resource levelling.
- Printing / PDF export.
- A grid package (or a custom virtualised grid) if projects grow to thousands of rows.
