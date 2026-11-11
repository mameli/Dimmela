#!/bin/bash
# Builds Dimmela in Release, signs it with the "Developer ID Application" certificate, has Apple
# notarize it (notarytool profile "dimmela", or "takku" if that is the one on this Mac, or
# $DIMMELA_NOTARY_PROFILE), staples the ticket, packs it into a disk image (scripts/dmg/make-dmg.sh),
# signs and notarizes that too, publishes it as a GitHub Release tagged v<MARKETING_VERSION> (from
# Config/Base.xcconfig) and points the Homebrew cask in the tap (a clone of mameli/homebrew-dimmela,
# ../homebrew-dimmela or $DIMMELA_TAP) to it. A published version is never replaced: Homebrew checks
# the disk image's SHA-256. The Release also carries a copy named Dimmela.dmg, so
# releases/latest/download/Dimmela.dmg always gives the latest version, and Dimmela.zip, the app
# zipped, for the links to it made up to 0.1.7. Adapted from Takku's script.
#
#   scripts/release.sh            build, sign and pack into build/release/, then ask before publishing
#                                 (a dry-run of the same commit is reused: no second build and notarization)
#   scripts/release.sh --dry-run  build, sign, notarize and pack only
#
# Once per Mac: the certificate from Xcode → Settings → Accounts → Manage Certificates, and
#   xcrun notarytool store-credentials dimmela --apple-id <Apple ID> --team-id <Team ID>
# with an app-specific password from account.apple.com.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig)
tag="v$version"
app=build/release/DerivedData/Build/Products/Release/Dimmela.app
zip=build/release/Dimmela.zip
dmg="build/release/Dimmela-$version.dmg"
latest=build/release/Dimmela.dmg
built=build/release/commit
tap=${DIMMELA_TAP:-../homebrew-dimmela}
cask="$tap/Casks/dimmela.rb"
identity="Developer ID Application"
notary=${DIMMELA_NOTARY_PROFILE:-dimmela}
# The credentials are the same Apple ID and team: the profile made for Takku works too.
if [[ -z ${DIMMELA_NOTARY_PROFILE:-} ]] && ! xcrun notarytool history --keychain-profile dimmela >/dev/null 2>&1; then
    notary=takku
fi

if [[ -n $(git status --porcelain) ]]; then
    echo "Commit or stash your changes first: the Release must match a commit." >&2
    exit 1
fi
if gh release view "$tag" >/dev/null 2>&1; then
    echo "Release $tag already exists: raise MARKETING_VERSION in Config/Base.xcconfig." >&2
    exit 1
fi
if [[ ! -f $cask || -n $(git -C "$tap" status --porcelain) ]]; then
    echo "The Homebrew tap must be a clean clone of mameli/homebrew-dimmela in $tap (or set DIMMELA_TAP)." >&2
    exit 1
fi
# The Release notes are this version's CHANGELOG section, with links that work outside the repo.
changes=$(awk -v head="## $version" '$0 == head { on = 1; next } /^## / { on = 0 } on' CHANGELOG.md \
    | perl -0777 -pe 's{\]\((?!https?:|#|mailto:)([^)]+)\)}{](https://github.com/mameli/Dimmela/blob/main/$1)}g; s/^\s+|\s+$//g')
if [[ -z $changes ]]; then
    echo "CHANGELOG.md has no \"## $version\" section." >&2
    exit 1
fi

# A dry-run leaves the notarized disk image and the commit it was built from in build/release/:
# publishing that same commit reuses them instead of building and notarizing everything again.
if [[ ${1:-} != --dry-run && -f $built && $(cat "$built") == $(git rev-parse HEAD) && -f $dmg && -f $latest && -f $zip ]]; then
    xcrun stapler validate -q "$dmg" || { echo "$dmg has no notarization ticket: delete build/release and run again." >&2; exit 1; }
    echo "Reusing $dmg: built and notarized from this commit by the dry-run."
else
    # The Team ID is the certificate's organizational unit.
    team=$(security find-certificate -c "$identity" -p 2>/dev/null | openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
        | sed -n 's/^ *organizationalUnitName *= *//p')
    if [[ -z $team ]]; then
        echo "No \"$identity\" certificate in the keychain: create it in Xcode → Settings → Accounts → Manage Certificates." >&2
        exit 1
    fi
    if ! xcrun notarytool history --keychain-profile "$notary" >/dev/null 2>&1; then
        echo "No notarytool profile \"$notary\": run xcrun notarytool store-credentials $notary --apple-id <Apple ID> --team-id $team" >&2
        exit 1
    fi

    rm -rf build/release
    # No get-task-allow entitlement: it is only for debugging (and notarization refuses it).
    # A secure timestamp is required by notarization.
    xcodebuild -project Dimmela.xcodeproj -scheme Dimmela -configuration Release \
        -derivedDataPath build/release/DerivedData \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$team" \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp \
        clean build | grep -E "error: |BUILD"

    codesign --verify --strict --deep "$app"
    [[ $(codesign -dvv "$app" 2>&1) == *"Authority=$identity"* ]] || { echo "Not signed with the $identity certificate." >&2; exit 1; }

    notarize() {
        xcrun notarytool submit "$1" --keychain-profile "$notary" --wait --output-format json > build/release/notary.json || true
        if [[ $(plutil -extract status raw -o - build/release/notary.json 2>/dev/null) != Accepted ]]; then
            cat build/release/notary.json >&2
            id=$(plutil -extract id raw -o - build/release/notary.json 2>/dev/null)
            [[ -n $id ]] && xcrun notarytool log "$id" --keychain-profile "$notary" >&2
            echo "Notarization of $1 failed." >&2
            exit 1
        fi
    }

    # The app is notarized as a zip and the ticket stapled to it, so Gatekeeper accepts it offline
    # once it is in Applications too. Then the disk image around it is signed, notarized and stapled.
    ditto -c -k --keepParent "$app" "$zip"
    notarize "$zip"
    xcrun stapler staple -q "$app"
    spctl --assess --type execute "$app" || { echo "Gatekeeper refuses the notarized app." >&2; exit 1; }
    # Zipped again with its ticket, for the old Dimmela.zip links.
    rm "$zip"
    ditto -c -k --keepParent "$app" "$zip"
    scripts/dmg/make-dmg.sh "$app" "$dmg"
    codesign --sign "$identity" --timestamp "$dmg"
    notarize "$dmg"
    xcrun stapler staple -q "$dmg"
    spctl --assess --type open --context context:primary-signature "$dmg" || { echo "Gatekeeper refuses the disk image." >&2; exit 1; }
    cp "$dmg" "$latest"
    git rev-parse HEAD > "$built"
    echo "Ready: $dmg (notarized)"
fi

[[ ${1:-} == --dry-run ]] && exit 0
read -r -p "Publish $tag on GitHub? [y/N] " answer
[[ $answer == y ]] || exit 0

if [[ $(git rev-parse HEAD) != $(gh api "repos/{owner}/{repo}/commits/main" --jq .sha) ]]; then
    echo "Push main first: the tag is created on the commit GitHub has." >&2
    exit 1
fi
gh release create "$tag" "$dmg" "$latest" "$zip" --target main --title "Dimmela $version" --notes-file - <<NOTES
### What's new

$changes

---

### How to install or update

1. Download **[Dimmela-$version.dmg](https://github.com/mameli/Dimmela/releases/download/$tag/Dimmela-$version.dmg)**.
2. If Dimmela is running, quit it from its menu at the top of the screen.
3. Open the downloaded file and drag **Dimmela** onto **Applications**. When your Mac asks, choose **Replace**.
4. Open Dimmela. Your settings, Modes and Vocabulary stay as they are.

With Homebrew: \`brew install --cask mameli/dimmela/dimmela\` (or \`brew upgrade --cask dimmela\`).

Apple Silicon Mac, macOS 15 or later. Dimmela is notarized by Apple: it opens like any other app. At the first launch a window walks you through the permissions and downloads the speech model (about 490 MB).
NOTES

# The cask points to this version's disk image. Pushed through gh, like the Release.
sha=$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)
git -C "$tap" pull --ff-only -q
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
    -e 's/Dimmela-#{version}\.zip"/Dimmela-#{version}.dmg"/' "$cask"
git -C "$tap" commit -q -am "Dimmela $version"
git -C "$tap" -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -q origin main
echo "Homebrew cask updated to $version."
