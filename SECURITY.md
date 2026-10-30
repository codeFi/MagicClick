# Security Policy

MagicClick sees every mouse and keyboard event on your Mac, so we take security seriously.

## What MagicClick can access

- **Accessibility permission.** MagicClick uses it to change clicks and to read the one key you choose as the middle button. It does not store or record other keys.
- **Touch positions** from the Magic Mouse and trackpad, through Apple's private MultitouchSupport framework.
- **No network.** MagicClick never connects to the internet and collects no data.
- **Settings** are stored in the normal macOS user defaults (`io.github.codefi.MagicClick`).

## Supported versions

Only the latest release gets security fixes.

| Version | Supported |
| --- | --- |
| 1.2.x (latest) | ✅ |
| Older | ❌ |

## Report a vulnerability

**Do not open a public issue for a security problem.**

Report it privately with GitHub:

1. Go to the [Security tab](https://github.com/codeFi/MagicClick/security) of this repo.
2. Click **Report a vulnerability**.
3. Tell us what the problem is, how to make it happen, and what an attacker could do with it.

If you cannot use GitHub, email **razvantanase@me.com** with "MagicClick security" in the subject.

## What happens next

- We reply within **7 days** to say that we got your report.
- We tell you if we agree that it is a problem, and how we plan to fix it.
- We fix it in a new release and credit you in the release notes, unless you want to stay anonymous.
- Please give us time to release a fix before you talk about the problem in public.

## Verify your download

The DMG on the Releases page is signed *ad hoc* and is not notarized. If you do not want to trust a download, read the code and [build it yourself](README.md#build-from-source).
