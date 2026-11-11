# Dimmela updates itself with Sparkle

Up to 0.1.7, *Dimmela … is available…* opened the GitHub release page: download, quit Dimmela, drag the new one into Applications. Since 0.2.0 Dimmela installs updates itself with [Sparkle](https://sparkle-project.org) 2, as Takku has done since its ADR 0014. *Dimmela … is available…* in the menu, or *Install…* in Settings › About, opens Sparkle's window with what is new and *Install Update*; Dimmela downloads the disk image, replaces itself and opens again.

We chose Sparkle over writing our own updater (download, verify, swap the bundle, relaunch). Sparkle already handles the parts that are easy to get wrong: verifying what was downloaded, replacing a running app, relaunching it and keeping the permissions.

- **Trust**: the appcast and the disk image come from GitHub, but Dimmela installs an update only if its EdDSA signature matches the public key in Dimmela's Info.plist (`SUPublicEDKey`). Sparkle also checks that the new app has the same Developer ID. The private key is in the keychain of the Mac that publishes, under account `dimmela` (made with Sparkle's `generate_keys`; it is not Takku's key). Back it up with the Developer ID certificate: if it is lost, no Dimmela can install updates until users install a new version by hand.
- **Feed**: `appcast.xml` is published as a file of every GitHub Release, and Dimmela reads `releases/latest/download/appcast.xml`. That address never moves and does not depend on dimmela.app being deployed. The appcast holds the latest version only, with the CHANGELOG section as its notes.
- **Never during a Dictation**: a relaunch would lose it, so the install waits until no Dictation is in progress (`shouldPostponeRelaunchForUpdate`).
- **No window by itself**: the daily check adds the version to the menu and to Settings › About, using Sparkle's gentle reminders. Sparkle's window opens only when the user chooses it. Turning *Check for updates* off in Settings stops the daily check. Sparkle sends no system profile.
- **Signing**: Xcode leaves Sparkle's helpers (Autoupdate, Updater.app and the XPC services) signed ad hoc, so `release.sh` signs each with the Developer ID, inside out, before notarization.

## Consequences

- Versions up to 0.1.7 cannot update themselves: their users update by hand one more time.
- The Homebrew cask says `auto_updates true`, so `brew upgrade` without the cask's name leaves Dimmela to update itself.
- A Debug build can try an update with `-testUpdateFeed <URL>`, pointing at an appcast served locally.
