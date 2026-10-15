# Third-party notices

Esplitéalo itself is not open source (see [LICENSE](LICENSE)). The components below are third-party works that keep their own licenses.

## Unkempt font

`design/brand/fonts/Unkempt-Bold.ttf`, `Unkempt-Bold-latin.woff2` and `Unkempt-Regular.ttf` are the Unkempt typeface, licensed under the **Apache License 2.0**. The full license text is in [`design/brand/fonts/LICENSE-Unkempt-Apache-2.0.txt`](design/brand/fonts/LICENSE-Unkempt-Apache-2.0.txt). The app uses it for the wordmark and display text only.

## Agent skills (`.claude/skills`)

Development-time instructions for AI coding assistants. They are not part of the app. Each folder carries its upstream license file; see [`.claude/skills/README.md`](.claude/skills/README.md) for sources and pinned commits.

| Skill | License | Copyright |
| ----- | ------- | --------- |
| `swiftui-expert-skill` | MIT | Antoine van der Lee |
| `apple-design-*` (six skills) | MIT | Ravishankar |

## Swift packages (tests only)

The app's snapshot tests use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) and its dependencies. They are resolved by Swift Package Manager, are not vendored in this repository, and are not shipped in the app.

| Package | License |
| ------- | ------- |
| swift-snapshot-testing | MIT |
| swift-custom-dump | MIT |
| xctest-dynamic-overlay | MIT |
| swift-syntax | Apache License 2.0 |

Their license texts are in their own repositories.
