# 02: Provider profiles

**What to build:** Replace the single Provider with named Provider profiles, as in Takku (`ProviderProfile.swift`, the Profile editor): each has a name, address, model, reasoning level, Extra parameters and its own API key in the Keychain. The user adds, edits, deletes and orders profiles in Settings › Post-processing and selects the one Post-processing uses.

**Blocked by:** none

**Status:** ready-for-agent

- [x] The current Provider and its key migrate to a first profile on upgrade, with nothing for the user to redo
- [x] Presets for the common providers (OpenRouter, OpenAI, Mistral, a local LM Studio / Ollama) fill address and model
- [x] Test Connection per profile
- [x] The selected profile can be changed from the menu bar menu too
- [x] The Post-processing log and the problem report name the profile's model, never its key or Extra parameters
- [x] `CONTEXT.md`: add **Provider profile**; ADR 0004 still holds

## Comments

### 2026-11-10: implemented (not committed)

- `ProviderProfile` / `ProviderProfiles` in DimmelaCore, saved as one JSON string under `providerProfiles` (works with `@AppStorage`).
- `AppSettings.migrateProviderIfNeeded()` turns the 0.1.7 Provider into the first profile and copies its key to the profile's Keychain item; the old keys and Keychain item are left for an older build.
- Settings › Post-processing: list with + (presets) / −, drag to reorder, editor of the chosen profile, *Use for Post-processing*. Menu bar: *Provider* picker when there is more than one.
- To verify by hand: the first launch of a signed build migrates without asking the Keychain twice.
