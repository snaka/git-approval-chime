# git-approval-chime

Plays a sound while git is stuck waiting for you to approve an SSH key use.

When your SSH key lives in 1Password (or Secretive, or any agent or signer that
asks before it signs), `git commit` and `git push` stop and wait for an approval
dialog. If you are away from the screen, or a coding agent ran the command for
you, nothing tells you, and the command eventually fails. git-approval-chime
chimes every few seconds from the moment the wait starts until you approve.

macOS only (it plays sounds with `afplay`).

## Install

```bash
brew install snaka/tap/git-approval-chime
git approval-chime install
```

`install` points two git settings at git-approval-chime and remembers what they
were:

| Setting | Covers | What it waits on |
|---|---|---|
| `gpg.ssh.program` | signed commits and tags | the signer (e.g. `op-ssh-sign`) to return |
| `core.sshCommand` | push, fetch, clone over SSH | ssh to finish authenticating |

Both are needed: signing and SSH authentication reach your key by different
routes, so each one can wait on its own.

`install` edits the file that already defines each setting, following
`[include]`, so a machine-local config file stays the place where machine
specific paths live. Run it again after moving the executable; it never
mistakes itself for the program it wraps.

To undo it:

```bash
git approval-chime uninstall
```

## How it decides you are being asked

It never looks at the screen. It times the step that only takes long when
someone has to approve it:

- **Signing** returns almost at once unless the signer is waiting for you.
- **SSH** runs with `LogLevel=VERBOSE` and stops the chime at
  `Authenticated to ...`, so a slow transfer after authentication stays
  silent. The extra lines that log level adds are filtered out.

## Settings

```bash
git config --global approval-chime.delay 5                                # seconds before the first chime (default 3)
git config --global approval-chime.sound /System/Library/Sounds/Ping.aiff # default Glass.aiff
```

## Test

```bash
./test/run.sh
```

Runs against fakes in a throwaway `HOME`: nothing is signed, contacted, or
played.

## License

MIT
