# How this app gets checked

There is no test target. Two scripts and one probe stand in for it, and the list below is
what they cannot cover.

```bash
python3 tools/verify_tax_engine.py        # must pass before any release
python3 tools/verify_payslip_reader.py    # must pass before any release
tools/payslip_probe/build.sh              # then: .build/payslip_probe <file.pdf|.png>

tools/payslip_corpus/build.sh                                 # generated payslips
.build/payslip_corpus generate --out docs/fixtures/corpus     # with an answer key
python3 tools/score_payslip_corpus.py --corpus docs/fixtures/corpus
```

A fresh clone cannot run all of it, and it is better to know that now than to run it and
wonder. The AT source workbooks are not in the repository, so `verify_tax_engine.py`
skips its round trip against them and says so on the way past. It still checks everything
else, including the invariants, which is the part no source document could give it.
`payslip_probe` compiles and then has nothing to read, because real payslips are
somebody's actual pay and are permanently gitignored. Supply your own.

`tools/payslip_corpus` is the answer to the problem in that last paragraph. It
generates payslips whose every figure comes from the app's own `TaxEngine`, so
unlike a real payslip they can be scored, and `score_payslip_corpus.py` runs the
shipping reader over them through the probe. It fails on two things and nothing
else: a `wrong` finding on a page generated to be correct, and a verdict on
something that is not a payslip. Everything else it prints is a budget rather
than a target, and the skip count in particular must never be optimised. The
results, and what the corpus cannot tell you, are in
[payslip-accuracy.md](payslip-accuracy.md). It found the space separator bug that
was dropping the thousands from every figure on the PDF text path.

The probe is not a pass or a fail and does not gate anything. It prints what the shipping
`Engine/` sources decide about a real file: every line with its concept, provenance and
confidence, then the facts, then the verdict. Its value is the diff across a change,
because there is no answer key for a payslip.

## The checks a compiler cannot do

Every one of these is here because it caught something real.

**1. Two bugs can cancel, and then either fix alone is a regression.** A column test
mislabelled every deduction on the payslip layout that stacks its two blocks vertically,
and a label fallback silently undid it. The reading on screen was correct and neither half
of it was. Before fixing something that looks obviously wrong inside a heuristic, capture
what the whole thing currently decides about a real input, and diff it afterwards. That is
what the probe is for.

**2. Code that makes a judgement cannot be checked by restating it in Python.** A script
can verify code that restates a table, because the table has a source to compare against.
`PayslipLayout`, `PayslipDocument`, `PayslipClassifier` and `PayslipReconciler` decide
things about a page, and a Python twin of a judgement is a second opinion rather than a
check. Compile the real thing and run it. Everything under `Engine/` imports only
Foundation, so this is always possible, and it found six bugs a script could not have.

**3. Check the invariant a comment claims, not the prose.** Three comments in the payslip
reader said it identified lines "without reading a single label". It reads labels first
and the arithmetic holds the veto. That is a good design described wrongly, and a
flattering comment is worse than none, because the next reader builds on a guarantee that
is not there.

**4. A skip reason has to name the actual reason.** Collapsing "these two figures differ"
and "we never found one of them" into a single boolean made the app tell a reader their
payslip withheld on a non-gross base when it had simply failed to read the base. Saying
why a check did not run is only worth doing if the why is true. Three states need three
states.

**5. Test the input the feature is for, not the input you have.** Recognition is not
deterministic across input paths: the same photograph read from a file and read through
the Photos picker produced different figures, and the second sent the net identity into
the year-to-date block. Nothing looked wrong on screen, because the "a total has to be a
total of something" rule retracted it. Neither the variance nor the rule earning its place
is visible from reading the code.

**6. When a constant becomes computed, check that nothing it now reads reads it back.**
Turning `Theme.ink` from a literal into `current.ink` meant a bulk edit replaced 52
hardcoded ink values, including the one inside `AccentTheme.ink` itself. That single line
made the two properties call each other until the stack ran out. No compiler error, no
warning, a crash on the first frame. Grep the new computed property's own definition
before anything else.

**7. When a design token stops being a constant, check every view that draws with it
observes what changes it.** SwiftUI cannot see a static change, so `Theme.accent` becoming
computed left eight views quietly stale. The tempting fix, `.id(store.accent)` on the
root, is worse than the bug: it rebuilds the whole tree and resets every `@State`,
including the sheet the user is standing in while tapping the swatches.

**8. When a value becomes reachable that previously was not, grep every filter that used
to exclude it.** Making Açores and Madeira selectable turned a `filter { $0.cohort != nil }`,
written when they were unreachable, into a silent failure: picking a Madeira município
stored correctly and then rendered everywhere as though nothing had been chosen. This
failure has no error message and no crash, which is what makes it worth its own line.

**9. The tracked file list must match the files actually on disk.** `SalarySeed/` is a
folder-synchronized group, so Xcode compiles every `.swift` under it whether or not git
knows about it. A file deleted from git but left on disk is still a file the compiler
reads. That is exactly how one release shipped a build error: four "unused" string
deletions were being used, by a file removed from git two versions earlier that had never
left the disk. After any `git reset --hard`, run `git clean -nd` and read what it lists.

**10. A plist key you asked Xcode to generate has to be read back out of the built
plist.** `INFOPLIST_KEY_` only maps the key names Xcode knows. One lands as a real
boolean, another is dropped on the floor with no warning at all. Read the built
`Info.plist`, not the build settings. That is the only reason there is a separate
`Info.plist` in this repository.

**11. `onChange` does not fire for the value a view already has.** A trigger written as
`onChange(of: scenePhase)` alone runs on backgrounding and on returning, and never on a
cold launch. Nothing fails visibly: the card looks healthy and does nothing. Any recurring
trigger needs its `.task` counterpart.

**12. `JSONEncoder` ignores the key order of your `encode(to:)`.** It fills a dictionary
and serialises that, so the order is arbitrary and differs between calls. Anything that
compares, signs or hashes encoded bytes needs `.sortedKeys`. This one comes from the
backend that did not ship, where it caused an unchanged row to be re-uploaded on every
launch, twice, for every user, with the correct data in the correct document the whole
time. Found only by logging what the server actually received.

**13. Round-trip anything generated.** Emit the Swift from the source data, parse the
Swift back, compare to the source. The regional tax tables are 45 rows nobody should ever
retype, and the concelho list and the Europe grid are the same shape of problem.

**14. Render the screen and look at it.** A build that succeeds is not a layout that
works. Do it at the default text size and again at `accessibility-extra-large`, then put
it back and confirm the default is unchanged, because the whole promise of `UIFontMetrics`
is that it does nothing until asked.

```bash
xcrun simctl ui <device> content_size accessibility-extra-large
```

**15. The camera cannot be checked in the Simulator, and it is the first thing in this app
that a simulator screenshot cannot confirm.** `VNDocumentCameraViewController.isSupported`
is true on an iOS 26 simulator, so the Photograph row IS drawn there and the permission
prompt really appears, which is enough to check the prompt's wording, the refusal path and
the Open Settings link. What cannot happen is a scan: there is no camera behind it. The
deskew, the contrast, the JPEG and everything `PayslipOCR` then does with them need a
device build, which is free on the personal team with a 7-day expiry. On device, check all
three permission states and all four ways out of the check, and open Photos afterwards to
confirm the scan was not saved.

## Resetting onboarding, which is harder than it looks

`hasOnboarded` lives in `UserDefaults.standard`, and on the Simulator that is **not** the
plist inside the app's data container. Three things that look like they should reset it and
do not:

- `xcrun simctl uninstall` removes the container, but `cfprefsd` keeps serving the old
  values to the reinstalled app. The plist on disk reads `{}` while the app still sees
  `hasOnboarded = 1`.
- Rebooting the simulator does not clear it either.
- `xcrun simctl spawn booted defaults write com.afonsoazevedo.salaryseed hasOnboarded
  -bool false` reports success, and `defaults read` shows `0`, and **the app still sees
  true**: `simctl spawn` and the app sandbox are not the same preference context. Passing a
  file PATH instead of the bundle id is worse again, because it silently addresses an empty
  domain and reports nothing at all.

What actually works, and it is the only thing that does:

```bash
xcrun simctl shutdown booted
xcrun simctl erase <udid>
xcrun simctl boot <udid>
./tools/run_sim.sh
```

An erase resets the device's text size too, so set `content_size` again afterwards, and it
resets the language, so a freshly erased device runs the app in English rather than
Portuguese. Both are useful in their own right: the erase is the only way to see a genuine
first run, which is the one thing worth being sure about on a screen every new reader meets.

The intro screen has the same problem and a much cheaper answer: **Profile has a replay
row** ("What the app does"), which sets the session flag and leaves `hasSeenIntro` alone.
Use that for everything except the handoff itself. The one thing it cannot show you is the
intro arriving out of onboarding's last step, which needs the erase above, and the one
thing to know when you do use it is that the intro then fades back onto Profile rather than
onto Home, because Profile is a pushed screen.

## A note on the numbers in the payslip comments

The worked figures throughout the payslip reader are stand-ins. Every relation they
demonstrate is real and still holds, and the token shapes in `PayslipNumber.parsingFixtures`
are exactly the ones that came off real payslips: the separators, the homoglyph, the
trailing sign. The digits inside them are not the measured ones, because the payslips this
was built against were somebody's actual pay. Change a shape and you are changing the
test. Change the digits and you are not.
