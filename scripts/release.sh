#!/bin/bash
# Builds Dimmela in Release, signs it with the "Developer ID Application" certificate, has Apple
# notarize it (notarytool profile "dimmela", or "takku" if that is the one on this Mac, or
# $DIMMELA_NOTARY_PROFILE), staples the ticket, zips it, publishes it as a GitHub Release tagged
# v<MARKETING_VERSION> (from Config/Base.xcconfig) and points the Homebrew cask in the tap (a clone
# of mameli/homebrew-dimmela, ../homebrew-dimmela or $DIMMELA_TAP) to it. A published version is
# never replaced: Homebrew checks the zip's SHA-256. The Release also carries a copy named
# Dimmela.zip, so releases/latest/download/Dimmela.zip always gives the latest version.
# Adapted from Takku's script.
#
#   scripts/release.sh            build, sign and zip into build/release/, then ask before publishing
#   scripts/release.sh --dry-run  build, sign, notarize and zip only
#
# Once per Mac: the certificate from Xcode → Settings → Accounts → Manage Certificates, and
#   xcrun notarytool store-credentials dimmela --apple-id <Apple ID> --team-id <Team ID>
# with an app-specific password from account.apple.com.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig)
tag="v$version"
app=build/release/DerivedData/Build/Products/Release/Dimmela.app
zip="build/release/Dimmela-$version.zip"
latest=build/release/Dimmela.zip
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

# Notarized as a zip, then the ticket is stapled to the app, so Gatekeeper accepts it offline
# too, and the app is zipped again with its ticket.
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$notary" --wait --output-format json > build/release/notary.json || true
if [[ $(plutil -extract status raw -o - build/release/notary.json 2>/dev/null) != Accepted ]]; then
    cat build/release/notary.json >&2
    id=$(plutil -extract id raw -o - build/release/notary.json 2>/dev/null)
    [[ -n $id ]] && xcrun notarytool log "$id" --keychain-profile "$notary" >&2
    echo "Notarization failed." >&2
    exit 1
fi
xcrun stapler staple -q "$app"
spctl --assess --type execute "$app" || { echo "Gatekeeper refuses the notarized app." >&2; exit 1; }
rm "$zip"
ditto -c -k --keepParent "$app" "$zip"
cp "$zip" "$latest"
echo "Ready: $zip (notarized)"

[[ ${1:-} == --dry-run ]] && exit 0
read -r -p "Publish $tag on GitHub? [y/N] " answer
[[ $answer == y ]] || exit 0

if [[ $(git rev-parse HEAD) != $(gh api "repos/{owner}/{repo}/commits/main" --jq .sha) ]]; then
    echo "Push main first: the tag is created on the commit GitHub has." >&2
    exit 1
fi
gh release create "$tag" "$zip" "$latest" --target main --title "Dimmela $version" --notes-file - <<NOTES
Apple Silicon Mac, macOS 15 or later.

With Homebrew: \`brew tap mameli/dimmela\` then \`brew install --cask dimmela\` (or \`brew upgrade --cask dimmela\`). Otherwise download \`Dimmela-$version.zip\` (\`Dimmela.zip\` is the same file), open it and move **Dimmela** to **Applications**.

Dimmela is notarized by Apple: it opens like any other app. At the first launch a window walks you through the permissions and downloads the speech model (about 490 MB).
NOTES

# The cask points to this version's zip. Pushed through gh, like the Release.
sha=$(shasum -a 256 "$zip" | cut -d ' ' -f 1)
git -C "$tap" pull --ff-only -q
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" "$cask"
git -C "$tap" commit -q -am "Dimmela $version"
git -C "$tap" -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -q origin main
echo "Homebrew cask updated to $version."
