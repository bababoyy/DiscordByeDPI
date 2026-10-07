# DiscordByeDPI — experimental LiveContainer proxy tweak

Preserve the three signed apps **SideStore + LiveContainer + Stremio**.
Inside LiveContainer, run **ByeDPIBg + Discord**, with this dylib assigned
only to Discord's tweak folder.

**This download is a source/build package, not a compiled dylib or IPA.**
The included GitHub Actions workflow builds an arm64 iOS dylib on macOS.
No Mac or Apple Developer membership is needed on your side for this workflow.
You need a GitHub repository with Actions available, your working LiveContainer
installation, and Discord/ByeDPIBg IPAs that LiveContainer can run.

## Quick build from Linux

1. Extract this package.
2. Create an empty GitHub repository (no README), with Actions enabled.
3. From the extracted `DiscordByeDPI` directory, run:

```bash
git init -b main
git add .
git commit -m "Add experimental Discord local SOCKS tweak"
git remote add origin https://github.com/YOUR-USERNAME/DiscordByeDPI.git
git push -u origin main
```

Use your existing GitHub authentication. Do not paste tokens into this chat.
If GitHub flags your commit author as unset, set it for this repository using
`git config user.name` and `git config user.email`, then repeat the commit.

4. Open the repository's **Actions** tab and the **Build DiscordByeDPI** run.
5. When successful, download the **DiscordByeDPI-arm64** artifact and unzip it.
   It contains `DiscordByeDPI.dylib`, a SHA-256 checksum, and installation steps.
   GitHub may require you to be signed in to download an artifact.
6. Follow [INSTALL.md](INSTALL.md).

GitHub's standard runners are free for public repositories; private repositories
have plan-specific allowances. This workflow uses `macos-15`, Apple SDK tools,
and no repository secrets or signing certificate. It gives the library an
ad-hoc signature; LiveContainer must re-sign it with its own identity.

## What the code does

It applies a local SOCKS5 configuration to default and ephemeral Foundation
session configurations, and to both public URLSession configuration factories.
The factory hooks make a copy so caller-owned configurations remain unchanged.
Existing HTTP/SOCKS proxy configuration is replaced; other session settings are
preserved. The default endpoint is `127.0.0.1:10800`.

The constructor also checks the local endpoint's SOCKS5 greeting. The check
contacts only localhost, does not authenticate to Discord, and does not test
whether any DPI strategy works. Diagnostics record hook events and local proxy
availability without URLs, tokens, request bodies, or account information.

## Limits that matter

- This library does **not** contain the ByeDPI engine. ByeDPIBg must be running
  simultaneously in LiveContainer and listening on the configured port.
- No Discord IPA or Discord source was available in the build session. No
  claims about current Discord network coverage have been verified.
- Raw sockets, Network.framework, CFStream connections, and native UDP/media
  stacks are not hooked. WebSocket coverage depends on its implementation.
- Shared sessions created before injection cannot be reconfigured. Sessions
  created through private initializers or a separate process can escape hooks.
- Proxy dictionary support varies by networking API and OS behavior. A visible
  dictionary is not proof that a connection actually goes through SOCKS.
- Background URLSessions may not be compatible with a localhost guest proxy.
- This is not a system-wide VPN or a Network Extension entitlement workaround.
- LiveContainer documents that remote push notifications do not work for guests.
- The selected ByeDPI strategy, DNS behavior, ISP filtering and the particular
  Discord IPA still require on-device testing. A proxy can be reachable while
  Discord remains blocked.

## Change the port

In the workflow's build step, set `env: { DBD_PROXY_PORT: 'YOUR_PORT' }`.
Locally on macOS: `DBD_PROXY_PORT=YOUR_PORT bash build.sh`.
Use the same port in ByeDPIBg. The configuration smoke test uses the default
10800; that test runs separately before the iOS build.

## Verification status

The Linux session can run `python3 tests/test_probe.py` and shell/YAML checks.
The workflow adds Foundation configuration smoke tests on macOS, an Apple SDK
iOS compile, and Mach-O/signature inspection. Those CI checks have **not** run
until a successful Actions run exists. The Foundation tests verify configuration
insertion and preserving caller settings; they do not validate actual routing.
Discord login, gateway messages, media and LiveContainer behavior require the
iPhone. Do not describe this prototype as working until those results exist.

## Next step after successful text networking

Embed and lifecycle-manage the ByeDPI engine within the library, replacing the
separate ByeDPIBg guest. That needs a separate build and test pass. SwByeDPI's
wrapper is AGPL-3.0; the upstream ByeDPI C repository is MIT. Check the exact
files and their licenses before choosing what to embed.

## Primary references (checked 2026-10-08)

- [LiveContainer tweak import, scope and signing](https://livecontainer.github.io/docs/guides/tweaks)
- [LiveContainer multitasking and limitations](https://github.com/LiveContainer/LiveContainer)
- [SwByeDPI library, app and strategy documentation](https://github.com/mIwr/SwByeDPI)
- [SwByeDPI SOCKS URLSession implementation](https://github.com/mIwr/SwByeDPI/blob/master/Sources/SwByeDPI/Util/SBDURLSessionUtil.swift)
- [Apple connectionProxyDictionary documentation](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/connectionproxydictionary)
- [GitHub hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

The network hook in this package is original code; SwByeDPI source is not bundled.
