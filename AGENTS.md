# Agent instructions

## Android invariants

- Use Godot 4.0 stable for validation and exports.
- Keep the Android package ID `org.badlandprototype.game` unchanged.
- Preserve the existing `Android` export preset unless the task explicitly requires a compatible change.
- Never commit keystores, signing passwords, tokens, generated APKs, or local SDK/JDK/tooling directories.
- Never create or push a production `v*` tag or GitHub Release without the user's explicit instruction.

## Definition of Done: ordinary development task

For a normal game or code change, the agent must:

1. Review the intended diff and confirm that no credentials or generated binaries are staged.
2. Run `./scripts/check.ps1` with Godot 4.0.
3. If the fast check succeeds, commit the intended changes with a clear message.
4. Push to the requested branch.
5. Stop. A push to `main` automatically starts CI, which validates, builds Android, and updates `dev-latest`.

Do not run `scripts/build_android.ps1`, create an APK, wait for GitHub Actions, poll GitHub API/CLI, or diagnose CI unless the user explicitly requests it.

The final response for an ordinary task should state what changed, the fast-check result, the commit SHA, and that the push started CI.

## When a full Android build is required

Run `scripts/build_android.ps1` only when:

1. The user explicitly asks to build an APK, verify Android build, create a release, or equivalent.
2. The task changes Android/export infrastructure: `export_presets.cfg`, Gradle, signing, package/version settings, or CI/CD.
3. The task diagnoses a known Android build failure.

For CI/CD changes, validate workflow syntax locally and inspect a remote run only when the user explicitly asks for that verification. CI remains the primary Android build authority for ordinary work.
