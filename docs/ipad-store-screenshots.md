# iPad App Store screenshots

Run the `iPad - App Store Screenshots` workflow from `codemagic.yaml` on `main`.
This workflow does not publish an app or require signing credentials. It boots
an available 13-inch iPad Pro simulator and runs the real app as a guest.

Download `ipad-screenshots.zip` from the build artifacts. Inspect all three
screenshots for layout problems, loading indicators, empty data, or alerts.
Only upload accurate, fully rendered screens to App Store Connect's iPad
13-inch screenshot slot. The workflow validates 2064 x 2752 pixel dimensions.

The workflow captures onboarding, sign-in, and the guest home screen. Live
property listings depend on the network and backend being available. A failed
capture must be diagnosed from the build log; do not substitute stretched
iPhone screenshots.

If Codemagic is currently using Workflow Editor, switch to YAML configuration
to select this workflow. The existing signed release workflow configured in
Workflow Editor remains the release path; switch back to it for release builds.
The older YAML App Store workflow requires separate credential groups and is
not needed for screenshots.

Local verification on Windows covers Dart analysis and Python syntax only.
The simulator capture itself must be validated on the Codemagic Mac.
