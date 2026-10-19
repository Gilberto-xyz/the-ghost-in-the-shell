# the ghost in the shell

![A small ghost nudges a mouse pointer while a green chat availability indicator stays lit](assets/hero.png)

**Keep Microsoft Teams from switching to Away during short periods when you are at your computer but not touching the keyboard or mouse.** This Windows script waits 4 minutes and 45 seconds, moves the pointer one pixel and back, and repeats once a minute until you use the computer again. It does not click or type.

Teams can still change your presence because of calls, meetings, a locked computer, sleep, or activity on another device. A green status is **not guaranteed**. See [Microsoft's explanation of Teams presence](https://learn.microsoft.com/en-us/microsoftteams/presence-admins).

## Install

1. Save `the-ghost-in-the-shell.ps1` in a folder you will not move.
2. Open PowerShell in that folder.
3. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\the-ghost-in-the-shell.ps1 -Action Install
```

This starts the script now and creates a scheduled task named **the ghost in the shell**. It starts again whenever you sign in to Windows. It cannot keep Teams Available before sign-in or while Windows is locked.

## Keep Windows awake, including on battery

The script needs an awake, unlocked Windows session. Check these settings if your display turns off or Teams still shows Away:

1. In Windows 11, open **Settings → System → Power & battery → Screen, sleep, & hibernate timeouts**. For the strongest always-on setup, set **Turn my screen off after** and **Make my device sleep after** to **Never** for both **On battery** and **Plugged in**. To use less power, choose a time longer than the script's 4-minute-45-second wait, such as 15 minutes. [Windows power settings](https://support.microsoft.com/en-us/windows/experience/power-battery/power-settings-in-windows-11)
2. If you use a laptop with its lid closed, review **Control Panel → System and Security → Power Options → Choose what closing the lid does**. Closing the lid can put the laptop to sleep even when the timeouts above say Never. Set the battery and plugged-in lid actions according to how you use the laptop. [Microsoft's lid and sleep guide](https://support.microsoft.com/en-us/windows/experience/power-battery/shut-down-sleep-or-hibernate-your-pc)
3. If the screen still locks, check **Settings → Personalization → Lock screen → Screen saver**. A screen saver can require sign-in when it resumes. Review its **Wait** time and **On resume, display logon screen** option. Also check **Settings → Accounts → Sign-in options** for Dynamic Lock or other lock settings if your PC has them. Change security settings only when permitted on your device. [Screen saver settings](https://support.microsoft.com/en-us/windows/configure-a-screen-saver-in-windows-a9dc2a0c-dc8e-9161-d270-aaccc252082a) · [Dynamic Lock](https://support.microsoft.com/en-us/windows/security/windows-security/account-protection-in-the-windows-security-app)

**Battery limit:** No setting can keep a laptop running indefinitely on battery. Keeping the screen and PC awake uses more power; recharge before the battery runs low. Your organization may enforce lock or sleep settings that this script cannot override.

## Start, stop, or remove it

Use the install command above and replace `Install` with:

| Action | What it does |
| --- | --- |
| `Status` | Shows whether the scheduled task is running. |
| `Stop` | Stops it until your next Windows sign-in. |
| `Start` | Starts it again. |
| `Uninstall` | Stops it and removes the scheduled task. |
| `Test` | Moves the pointer once and checks that Windows recorded it. |

For example, to remove it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\the-ghost-in-the-shell.ps1 -Action Uninstall
```

To change the timing, edit `$idleSeconds` and `$repeatSeconds` near the top of the script. Requires Windows 10 or 11 and Windows PowerShell 5.1.
