# Toolchain support policy

Version review: 2 November 2026. LTS is used only when the upstream project
actually provides that support channel. Stable is not a promise of long-term
support.

| Component | Project selection | Upstream support model |
| --- | --- | --- |
| Flutter | 3.47.9, revision `c197ca5199e9ee5661e865596c9c07294dfab51c` | Latest stable; no official LTS channel |
| Dart | 3.13.7, bundled with Flutter | Latest stable minor only; no LTS channel |
| Node.js | 24.x | Maintenance LTS through 30 April 2028 |
| Java | 17 for Android CI and bytecode; 21 in the Linux builder | LTS release lines; use current vendor patch releases |
| Linux CI and builder | Ubuntu 24.04 | LTS; standard security maintenance through May 2029 |
| Production nginx | 1.30.6, image pinned by digest | Stable branch, not an LTS guarantee |
| Production Alpine | 3.24.3 in the pinned nginx image | Main packages supported through 1 June 2028; community packages through the next stable release |
| Android Gradle Plugin / Gradle / Kotlin | 9.0.1 / 9.1.0 / 2.3.20 | Release-based projects, not LTS SDK channels; compatibility is verified by Android builds |
| Dart/npm packages and GitHub Actions | Lockfiles and commit-pinned actions | No universal LTS designation; review upstream releases, vulnerabilities, and compatibility |
| macOS/Xcode and browser test tools | Hosted macOS 15 runner and stable browser | Platform/vendor release cycles, not LTS channels |

Flutter and Dart are upgraded together. The Dart minimum constraint is 3.13.0
because `web 1.1.2` requires it. Flutter is pinned in CI, the Docker builder, and
the Linux golden-test script; update all three together. Node 24 remains on its
supported LTS line instead of requiring a new Node major for this SDK migration.

The Docker builder is based on a pinned Ubuntu 24.04 image and checks out the
exact Flutter revision. Its base-image digest must be refreshed periodically
for operating-system and JDK security patches. A pinned digest gives
reproducibility; it does not keep an image updated automatically.

Dependabot continues to monitor Dart, npm, Docker, and GitHub Actions. The
nginx 1.31 mainline series is excluded so routine updates keep the runtime on
its selected stable branch. Reassess the stable branch when nginx publishes
its next stable series; do not keep an end-of-support branch indefinitely.

Android API 24 remains a deliberate minimum-compatibility test target. Its age
is not a claim that this operating system receives LTS security updates.
The Flutter 3.47 SDK also raises the minimum iOS deployment target to iOS 15.
Physical-device navigation certification remains separate from automated tests.

## Sources

- [Flutter stable channel](https://docs.flutter.dev/install/archive)
- [Flutter security policy](https://github.com/flutter/flutter/security/policy)
- [Dart SDK support policy](https://dart.dev/tools/sdk)
- [Node.js release schedule](https://github.com/nodejs/Release)
- [Ubuntu release lifecycle](https://ubuntu.com/about/release-cycle)
- [Java support roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)
- [nginx stable and mainline releases](https://nginx.org/en/download.html)
- [Alpine release support](https://alpinelinux.org/releases/)
