#!/usr/bin/env bash
#
# Create the release signing keystore and upload it to GitHub Actions secrets.
#
# Run this ONCE. The key it generates becomes your app's permanent identity:
# Android only allows an installed app to be updated by a build signed with the
# same key, so this key can never be rotated without forcing every user to
# uninstall and lose their data. Back up the generated .jks and its password
# somewhere durable -- losing them means you can never ship an update again.
#
#   ./scripts/ci-keystore.sh                 # generate + upload
#   ./scripts/ci-keystore.sh --upload-only   # re-upload an existing keystore
#
set -euo pipefail

KEYSTORE="${KEYSTORE:-release.jks}"
ALIAS="${ALIAS:-release}"
VALIDITY_DAYS="${VALIDITY_DAYS:-10950}"   # ~30 years; must outlive the app
DNAME="${DNAME:-CN=airplay-receiver, OU=Release, O=airplay-receiver, C=US}"
UPLOAD_ONLY=0
[[ "${1:-}" == "--upload-only" ]] && UPLOAD_ONLY=1

command -v keytool >/dev/null || { echo "keytool not found; install a JDK or set JAVA_HOME/bin on PATH" >&2; exit 1; }
command -v gh      >/dev/null || { echo "gh not found; install the GitHub CLI" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated; run: gh auth login" >&2; exit 1; }

if [[ $UPLOAD_ONLY -eq 0 ]]; then
  if [[ -e "$KEYSTORE" ]]; then
    echo "refusing to overwrite existing $KEYSTORE" >&2
    echo "re-upload it instead with: $0 --upload-only" >&2
    exit 1
  fi

  # A generated password is stored only in the GitHub secret and in the
  # local.properties written beside the keystore. Record both before deleting.
  PASS="$(openssl rand -base64 30 | tr -d '\n/+=' | cut -c1-32)"

  keytool -genkeypair -noprompt \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 4096 \
    -validity "$VALIDITY_DAYS" \
    -storepass "$PASS" -keypass "$PASS" \
    -dname "$DNAME"
  echo "generated $KEYSTORE (alias=$ALIAS, RSA 4096, ${VALIDITY_DAYS}d)"
else
  [[ -e "$KEYSTORE" ]] || { echo "$KEYSTORE not found" >&2; exit 1; }
  read -rsp "keystore password: " PASS; echo
fi

# CI decodes this to local.properties; build.gradle.kts reads these four keys
# and signs the release variant itself, so no separate signing action is needed.
LOCAL_PROPS="$(printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n' \
  "upload.jks" "$PASS" "$ALIAS" "$PASS")"

base64 < "$KEYSTORE" | tr -d '\n' | gh secret set STORE
printf '%s' "$LOCAL_PROPS" | base64 | tr -d '\n' | gh secret set LOCAL

echo
echo "uploaded secrets STORE and LOCAL to $(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo
echo "BACK UP NOW -- these cannot be recovered and cannot be rotated:"
echo "  keystore: $(cd "$(dirname "$KEYSTORE")" && pwd)/$(basename "$KEYSTORE")"
echo "  password: $PASS"
echo "  alias:    $ALIAS"
echo
echo "Keep $KEYSTORE out of git (it is covered by *.jks in .gitignore)."
