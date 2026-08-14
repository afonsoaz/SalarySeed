#!/bin/bash
#
# v1.0: the build phase that stops the app shipping without a privacy manifest,
# or with one that has quietly started claiming to collect something.
#
# Two of the three checks below exist because nothing else in the build would
# notice. The manifest reaches the bundle through the folder-synchronized group
# rather than through an explicit membership, so no file in the project names it:
# if it stopped arriving, every build would still succeed and Apple's rejection
# would turn up days later by email.
#
# Runs as the last phase of the SalarySeed target. Everything it reads comes from
# the build environment, so it is not runnable by hand without one.

set -euo pipefail

MANIFEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/PrivacyInfo.xcprivacy"
SOURCE_MANIFEST="${SRCROOT}/SalarySeed/PrivacyInfo.xcprivacy"

fail() {
    # The `error:` prefix is what makes Xcode show this in the issue navigator
    # rather than burying it in the build log.
    echo "error: $1"
    exit 1
}

# 1. It exists.
[ -f "${SOURCE_MANIFEST}" ] || fail "PrivacyInfo.xcprivacy is missing from SalarySeed/. Apple rejects builds that touch UserDefaults without one (ITMS-91053)."

# 2. It reached the bundle.
[ -f "${MANIFEST}" ] || fail "PrivacyInfo.xcprivacy exists in SalarySeed/ but did not reach the app bundle. Check that the synchronized group still copies it as a resource."

# 3. It still declares no collection.
#
# This app collects nothing, and there is no code in it that could: no
# URLSession, no endpoint, no analytics, no third-party SDK. So the array is
# empty, App Store Connect's App Privacy answer is "Data Not Collected", and the
# two agree.
#
# A diff that fills this in is therefore not a small change. It means something
# started leaving the phone, and the App Privacy questionnaire has to change in
# the same submission, which no build phase can check. Fail here so that at least
# the first half is impossible to do by accident.
COLLECTED=$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyCollectedDataTypes" "${SOURCE_MANIFEST}" 2>/dev/null | grep -c "NSPrivacyCollectedDataType " || true)
if [ "${COLLECTED}" -ne 0 ]; then
    fail "PrivacyInfo.xcprivacy now declares collected data types, but this app has no way to collect anything. If that changed, update App Store Connect's App Privacy answers in the same submission and then relax this check deliberately."
fi

echo "Privacy manifest checked: present in the bundle, declares no collection."
