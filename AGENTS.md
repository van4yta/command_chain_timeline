# AI implementation rules

- Keep execution and log collection out of this package.
- Render only `CommandLogSnapshot` values supplied by the caller.
- Do not add file pickers, storage, upload, or application-specific navigation to the package.
- The same snapshot must render in the source application and in an independent viewer application.
- Preserve usability for large logs; avoid building off-screen timeline elements unnecessarily.
- Export only `CommandChainTimeline` and `CommandChainTimelineLocale` from the
  package entrypoint. State, canvas, painter, selection, localization-helper,
  and details-panel types stay internal.
- Prefer pure functions. Do not extract logic into private helper methods; keep it inline or extract a public helper class with explicit inputs.
