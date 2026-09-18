# Agent instructions

## Android invariants

- Use Godot 4.0 stable for validation and exports.
- Keep the Android package ID `org.badlandprototype.game` unchanged.
- Preserve the existing `Android` export preset unless the task explicitly requires a compatible change.
- Never commit keystores, signing passwords, tokens, generated APKs, or local SDK/JDK/tooling directories.
- Never create or push a production `v*` tag or GitHub Release without the user's explicit instruction.

## Definition of Done

Before declaring a repository change complete, the agent must:

1. Review `git diff` and confirm no credentials or generated binaries are staged.
2. Run a Godot 4.0 headless project validation.
3. Run a local Android APK build check through `scripts/build_android.ps1`.
4. Verify the resulting APK exists and is non-empty; keep it ignored by git.
5. Validate any changed GitHub Actions workflow as far as local tooling permits.
6. Commit the intended changes with a clear message.
7. Push the commit to the requested branch.
8. If GitHub Actions starts and access is available, monitor the run and fix failures until it succeeds; never claim remote CI succeeded without observing a successful run.
