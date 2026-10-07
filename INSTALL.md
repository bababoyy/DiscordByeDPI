# iPhone installation and first test

This guide applies to the compiled **DiscordByeDPI-arm64** Actions artifact.
If you only have the source ZIP, build it first using README.md.

## Keep your signed apps

SideStore, Stremio and LiveContainer remain the installed/signed apps.
Discord and ByeDPIBg are imported as LiveContainer guests. Use **ByeDPIBg**,
the SOCKS background build, rather than the full Network Extension VPN build.

You need a Discord IPA that already launches under LiveContainer. This package
does not supply or decrypt Discord. First establish that Discord can open; a
blocked connection is a different failure from an IPA that cannot launch.

## Prepare the local proxy

1. Import ByeDPIBg into LiveContainer.
2. Launch it using LiveContainer's **Multitask** action.
3. Configure/start its SOCKS listener at **127.0.0.1:10800** (or your custom build
   port). Confirm the app's actual port; do not assume it is 10800 by default.
4. Select/test a DPI strategy against the Discord domains using the app's
   available controls. Strategy success depends on your network. We have not
   selected a verified Turkey/ISP-specific strategy for you.
5. Leave ByeDPIBg running. The silent audio/background mechanism still requires
   a device test; do not assume it will survive suspension indefinitely.

LiveContainer's multitasking requires that **Keep App Extensions** was selected
when installing LiveContainer through SideStore/AltStore. If you removed those
extensions, the documented multitasking setup is not available as-is.

## Assign the tweak only to Discord

1. In LiveContainer's **Tweaks** tab, create a folder named **DiscordByeDPI**.
2. Inside that folder, use **Import Tweak** to import `DiscordByeDPI.dylib`.
3. In Discord's app settings, select that folder as its **Tweak Folder**.
4. Ensure **Don't Inject TweakLoader** / **Don't Load TweakLoader** are disabled.
5. Let LiveContainer sign the tweak, or use the **Sign** button manually.
6. Fully stop Discord, then reopen it using **Multitask**, while ByeDPIBg is
   still running.

Use the app-specific subfolder, not the global Tweaks root. Runtime hooks affect
the process that loads this library; app-specific loading limits that scope but
is not a separate security sandbox. LiveContainer warns that guests are not
sandboxed from each other's data.

## Test in this order

1. **Launch:** Does Discord open without crashing?
2. **Login/API:** Can you sign in and load servers/channels?
3. **Gateway:** Can you send and receive a new message without reconnecting?
4. **Attachments:** Can you open an image?
5. **Voice:** Try last; this prototype does not hook UDP/native media networking.
6. **Lifecycle:** Lock/unlock the phone, return to Discord and check whether the
   local proxy is still running and realtime messages recover.

## Diagnostics

The library writes `DiscordByeDPI-status.txt` in the process's Documents
directory and sends the same events to the system console. In LiveContainer,
inspect/export Discord's data container if that version exposes it. Guest path
redirection can affect where the file lands; its exact location must be checked
on your installed version.

| Diagnostic/result | Meaning and next action |
| --- | --- |
| No loaded message/status file | Check tweak selection/signing; the file may also be inaccessible or redirected. This alone does not prove the tweak failed to load. |
| SOCKS5 check failed (2) | Local connection failed; check whether ByeDPIBg is running and listening on the same port. |
| SOCKS5 check failed (3) | Connected but handshake exchange failed or timed out. |
| SOCKS5 check failed (4) | Endpoint did not accept SOCKS5 without authentication. |
| SOCKS5 greeting OK | Listener works; DPI circumvention and Discord routing remain unproven. |
| URLSession factory observed | The tweak applied settings to a Foundation session; it does not prove a connection obeyed them. |
| API works but reconnecting persists | Investigate gateway transport; it may bypass these hooks. |
| All text works, voice fails | Investigate the media path separately. |

Return the relevant diagnostic lines, Discord IPA version, LiveContainer
version, iOS version, and which test first failed. Do not send account tokens
or passwords.

## Undo

Stop Discord, clear its **Tweak Folder** selection or remove the dylib, and
relaunch. Stop ByeDPIBg. No system VPN profile is installed by this tweak.
