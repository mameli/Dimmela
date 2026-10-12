# Native Swift, not Tauri or a fork of Handy

Dimmela exists because Handy, built with Tauri, uses too much memory for a tool that sits in the menu bar all day (922 MB footprint measured on 2026-10-12, with Parakeet loaded). Dimmela is a native Swift/SwiftUI app for Apple Silicon that runs Parakeet TDT v3 through FluidAudio on CoreML and the Neural Engine, and reuses code copied from Takku, which made the same choice (Takku ADR 0002).

Forking Handy was rejected: it keeps the webview and the Rust runtime that cause the footprint, and the hard parts of a dictation app on macOS (TCC permissions, CGEventTap, pasteboard, Keychain, audio devices) are first-class only in native code.

## Consequences

- macOS only, Apple Silicon only, macOS 15 or later.
- Memory is a requirement, not a wish: under 60 MB without the model, under 450 MB with Parakeet loaded. A spike measures it before the rest is built.
