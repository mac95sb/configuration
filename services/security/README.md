# Privileged runtime

Mise always runs as `mac`, including postinstall. `daemon:install` is the explicit
administrative boundary: review the checkout and selected tools before invoking
it. Its elevated deployment script copies selected binaries as root-owned regular
files and tasks/helpers beneath `/usr/local/libexec/mac-server`. Root daemons do
not follow executable links into a user's tool installation or run Mise.

Protected paths reject symlinks, unsafe ownership, writable parent chains and
extended ACLs. Private work/credentials have root-only ancestors. Deployment
replaces individual files through adjacent temporary files; it is not an atomic
all-runtime upgrade. Failure never activates the new boot configuration.

Fnox is restricted to the fixed age provider/key-file path, four service profiles,
and exact secret-name allowlists. Hooks, executable providers, imports, global
defaults and environment-control variables are rejected. A clean root launcher
resolves one explicit profile, then its fixed child drops to the service UID,
preserving only named secret variables. Values never appear in argv; the age
identity is not passed to applications. Keep sudo's normal env_reset policy.

Service users limit the impact of a compromised application. Forgejo owns its
data; the monitoring account does not need write access to it or your personal
credentials. Homebrew app binaries and user service configurations are opened
only after dropping privileges. Existing legacy accounts/data are not deleted.

Root captures protected backup sources, then Restic runs as `mac` against iCloud.
The per-operation handoff intentionally gives the host owner access to captured
data and the repository password, not the age identity or other service profiles.
Do not treat the personal `mac` account as an untrusted tenant. Success metrics
are written after dropping to the collector account, not by opening group-writable
collector paths as root. No ciphertext mirror or courier is involved.

Pitchfork's root boot job uses the protected binary, `/var/empty`,
`XDG_CONFIG_HOME=/etc` and disabled implicit supervisor startup. Activation rejects
unknown supervisor states and stops applications before supervisors. `--stage`
does not register/start jobs or configure logs; recovery tool installs suppress
postinstall provisioning with `MISE_SETUP_IN_PROGRESS=1`.

Recovery compares all existing credentials before installing anything and never
replaces differing identities/passwords. Installation requires stopped server jobs,
an inspected root-private stage, new service destinations and an explicit new
bootstrap-preservation container. The verified stage is kept. Deployment, identity
mapping and actual erased-host recovery still require a separate real rehearsal.
Keep destination parents unchanged during installation: stop all application
writers and other user sessions before accepting a staged recovery.
