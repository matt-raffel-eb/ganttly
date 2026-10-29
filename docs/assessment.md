# Flutter for a desktop project management app: assessment

*2026-10-29 · Matt Raffel with Claude. The original is in the Briefcase (misc project). This copy started the project.*

**Question:** Is Flutter the right stack for a desktop project management tool (like MS Project)? The main goals are (a) creating and editing work, (b) seeing it in a Gantt chart that updates in real time and exports to PNG on demand, and (c) saving and loading project data.

**Short answer: yes. Flutter is a good fit,** as long as you plan to build the Gantt chart yourself, and you probably should anyway.

## Why it fits

- **The Gantt chart is drawing work, and drawing is Flutter's strength.** Flutter paints every pixel itself, so a custom Gantt (bars, milestones, dependency arrows, a today line, weekend shading) is natural to build, and it updates smoothly as you edit.
- **PNG export is nearly free.** Flutter can capture any part of the screen as an image.
- **One codebase for Mac and Windows** (and Linux), and Flutter's desktop support is stable.
- **Skills carry over** from existing Flutter work.
- **Save and load are straightforward:** a JSON project file and the standard file dialogs. MS Project XML is doable later.

## The real risks aren't Flutter

1. **The scheduling engine is the hard part.** Build it as plain Dart, separate from the screen, with thorough tests.
2. **The editable task grid** (inline editing, keyboard navigation, indenting, reordering). Ready-made Flutter grids are commercial or less polished.
3. **Desktop polish:** menus, shortcuts, undo/redo, multiple windows (still limited).
4. **No ready-made Gantt to lean on;** plan to build it.

## When to choose something else

- **MS Project-level features quickly** (critical path, resource levelling, baselines): Tauri or Electron plus a commercial Gantt library (Bryntum, DHTMLX).
- **Windows-only enterprise:** .NET.

## Recommendation

Use Flutter: a pure-Dart scheduling engine as the single source of truth, the grid and the chart as two views of the same data, JSON files first and MS Project XML later. Start with the engine and the chart, then editing.
