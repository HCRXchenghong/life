# Daylink repository guidance

- Preserve the clean-room boundary from C-SSH. Implement behavior from public facts; do not copy names, assets, protocols, or private implementation details.
- Keep Dart as the owner of `app.db` and Rust as the owner of `vault.db`.
- Never log API keys, SSH secrets, raw authorization tokens, private keys, or full remote command output.
- Every mutating AI/SSH tool needs a stable schema, risk classification, approval rule, timeout, cancellation path, and audit event.
- Use `dart format`, `flutter analyze`, `flutter test`, `cargo fmt --check`, `cargo clippy`, `cargo test`, and Web build/tests before a release handoff.
- Do not make iOS promises for continuously running background SSH sockets or local port forwards.

