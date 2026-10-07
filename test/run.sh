#!/bin/bash
# Exercises both wrapper roles and install/uninstall against fakes, in a
# throwaway HOME. Nothing real is signed, contacted, or played.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

export HOME=$t/home GIT_CONFIG_NOSYSTEM=1 PATH="$t/bin:$root:$PATH"
mkdir -p "$HOME" "$t/bin"
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# afplay records each chime instead of playing it.
printf '#!/bin/bash\necho x >> "%s/chimes"; sleep 0.2\n' "$t" > "$t/bin/afplay"
# Signer: waits WAIT seconds (the "approval"), echoes stdin and args, exits 7.
printf '#!/bin/bash\nsleep "${WAIT:-0}"; cat; echo "args:$*"; exit 7\n' > "$t/bin/fake-sign"
# ssh: authenticates after WAIT, transfers for XFER, exits 5.
cat > "$t/bin/ssh" <<'EOF'
#!/bin/bash
[ "$1 $2" = "-o LogLevel=VERBOSE" ] || { echo "missing LogLevel" >&2; exit 99; }
sleep "${WAIT:-0}"
echo 'Authenticated to example.com ([192.0.2.1]:22) using "publickey".' >&2
sleep "${XFER:-0}"
cat; echo "remote stderr" >&2
echo 'Transferred: sent 1, received 2 bytes, in 0.1 seconds' >&2
echo 'Bytes per second: sent 1.0, received 2.0' >&2
exit 5
EOF
chmod +x "$t/bin/"*

git config --global approval-chime.delay 1
git config --global approval-chime.sign-program fake-sign
chimes() { [ -f "$t/chimes" ] && wc -l < "$t/chimes" | tr -d ' ' || echo 0; }
run() { rm -f "$t/chimes"; out=$(echo in | "$@" 2> "$t/err"); rc=$?; sleep 0.5; }

run env WAIT=3 git-approval-chime -Y sign -n git f
check "sign: chimes while waiting" '[ "$(chimes)" -ge 1 ]'
check "sign: passes stdin, args and exit code" '[ "$out" = "in"$'"'\n'"'"args:-Y sign -n git f" ] && [ $rc = 7 ]'
n=$(chimes); sleep 2
check "sign: chime stops when signer returns" '[ "$(chimes)" = "$n" ]'

run env WAIT=0 git-approval-chime -Y sign -n git f
check "sign: silent when signer returns at once" '[ "$(chimes)" = 0 ]'

run env WAIT=3 git-approval-chime -o SendEnv=GIT_PROTOCOL example.com git-upload-pack x
check "ssh: chimes while authenticating" '[ "$(chimes)" -ge 1 ]'
check "ssh: stdout to stdout, stderr to stderr, exit code" '[ "$out" = in ] && [ "$(cat "$t/err")" = "remote stderr" ] && [ $rc = 5 ]'

run env XFER=3 git-approval-chime example.com git-upload-pack x
check "ssh: silent on a slow transfer after auth" '[ "$(chimes)" = 0 ]'

# install / uninstall, with the signer defined in an included file.
rm -f "$HOME/.gitconfig"
printf '[include]\n\tpath = ~/.gitconfig.local\n' > "$HOME/.gitconfig"
git config --file "$HOME/.gitconfig.local" gpg.ssh.program /x/op-ssh-sign
git approval-chime install > /dev/null
git approval-chime install > /dev/null
check "install: replaces the value in the included file" '[ "$(git config --file "$HOME/.gitconfig.local" gpg.ssh.program)" = "$root/git-approval-chime" ]'
check "install: twice still saves the original signer" '[ "$(git config --get approval-chime.sign-program)" = /x/op-ssh-sign ]'
check "install: puts an unset core.sshCommand beside gpg.ssh.program" '[ "$(git config --file "$HOME/.gitconfig.local" core.sshCommand)" = "$root/git-approval-chime" ]'
git approval-chime uninstall > /dev/null
check "uninstall: restores the signer" '[ "$(git config --get gpg.ssh.program)" = /x/op-ssh-sign ]'
check "uninstall: unsets core.sshCommand" '! git config --get core.sshCommand > /dev/null'
check "uninstall: drops the saved key" '! git config --get approval-chime.sign-program > /dev/null'

[ $fails = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
