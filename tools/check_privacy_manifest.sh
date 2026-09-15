#!/bin/bash
#
# v1.0: the build phase that stops the app shipping without a privacy manifest,
# or with one that has quietly started claiming to collect something.
#
# v1.4 added a fourth check, for the camera usage description, for the same
# reason as the others: nothing else in the build would notice. A missing
# NSCameraUsageDescription is loud in the end (iOS kills the app the instant the
# scanner touches the capture session) but it is loud only to somebody who gets
# as far as tapping Photograph on a real device, which the simulator cannot do
# at all. Rule 10 says to read a generated plist key back out of the BUILT
# plist, and this is where that happens.
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
BUILT_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

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

# 4. The camera prompt reached the BUILT plist. Rule 10.
#
# It is set through INFOPLIST_KEY_NSCameraUsageDescription, and Xcode maps only
# the key names it knows: INFOPLIST_KEY_CFBundleLocalizations is dropped on the
# floor without a warning, which is the entire reason the root Info.plist
# exists. So the setting being present in project.pbxproj proves nothing, and
# this reads the value back out of the file that actually shipped.
#
# It is deliberately English only. The system draws this alert out of the bundle
# and follows the PHONE's language, not the app's own setting, so no .lproj
# could make it agree with the app anyway; the bilingual explanation is on
# screen before the button is tapped. See PayslipSourceStep.
CAMERA=$(/usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" "${BUILT_PLIST}" 2>/dev/null || true)
if [ -z "${CAMERA}" ]; then
    fail "NSCameraUsageDescription is missing from the built Info.plist. The payslip scanner needs it, and without it iOS terminates the app the moment the camera is touched. Set INFOPLIST_KEY_NSCameraUsageDescription in both build configurations."
fi

echo "Privacy manifest checked: present in the bundle, declares no collection."
echo "Camera prompt checked: present in the built Info.plist."
