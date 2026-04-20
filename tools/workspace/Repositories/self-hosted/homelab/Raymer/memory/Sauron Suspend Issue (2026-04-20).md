# Sauron Suspend Issue (2026-04-20)

## Problem
The Ubuntu workstation "Sauron" was not suspending automatically after 30 minutes of idle time, despite `IdleAction=suspend` and `IdleActionSec=30min` being configured in `/etc/systemd/logind.conf`.

## Diagnosis
Upon inspection with `loginctl`, it was found that two active SSH sessions (`108` and `3`) for user `aj` were present. Further investigation of `loginctl session-status 3` revealed that session `3` was in a `closing` state but was being held open by an attached `tmux` session named `ai` (`tmux new -s ai`).

`systemd-logind` prevents automatic suspend when there are active login sessions, even if they are idle, or in a `closing` state due to a lingering process like `tmux`.

## Solution
The immediate issue was resolved by identifying and killing the stuck `tmux` session on Sauron:

```bash
tmux kill-session -t ai
```
After killing the `tmux` session, the lingering session `3` was able to properly close, and `systemd-logind` could then enforce the idle suspend policy.

## Long-Term Recommendations for Reliable Suspend

To prevent similar issues with active sessions or lingering processes blocking suspend, consider these options:

### 1. Configure `systemd-logind` to ignore user sessions for suspend (recommended for persistent SSH users)
Modify `/etc/systemd/logind.conf` or create a drop-in configuration file (e.g., `/etc/systemd/logind.conf.d/ignore-sessions.conf`) with the following:

```ini
[Login]
IdleAction=suspend
IdleActionSec=30min
# This setting tells logind not to kill user processes on session close,
# but it also can affect how idle suspend is handled with active sessions.
# For a server that you SSH into frequently, you might set KillUserProcesses=no
# or explicitly configure which users/sessions to ignore if needed.
# More robust might be to allow suspend even if user sessions are active,
# but this often means overriding default behavior more broadly.
# A simpler and often more effective approach for servers is a cron-based suspend.
```

**Note:** The `KillUserProcesses=no` setting should be used with caution as it changes the default behavior of systemd regarding user processes. For a server, this might be acceptable.

### 2. Implement a cron-based forced suspend (most robust for servers)
This approach bypasses `systemd-logind`'s session-based inhibition and forces suspend after a set idle period, regardless of active sessions.

Add the following entry to your crontab on Sauron (run `crontab -e`):

```cron
*/30 * * * * /usr/bin/systemd-inhibit --who="idle-cron" --why="Force suspend on idle" /usr/bin/systemctl suspend
```
This command runs every 30 minutes, and if the system is truly idle (no other inhibitors from processes running), it will issue a suspend command. The `--who` and `--why` flags help in identifying the inhibitor if you check `systemd-inhibit --list`.

## Manual Suspend Command
To manually put Sauron to sleep at any time (from your laptop via SSH or directly on Sauron):

```bash
ssh sauron 'sudo systemctl suspend'
```
or
```bash
sudo systemctl suspend
```
This requires `sudoers` to be configured for passwordless suspend if run remotely without a password prompt.
