# guix-homelab

The machines. Every host here keeps itself in sync with this repository — push
a commit, and they follow.

This is not a Guix channel. It is the repository the agent watches.

```
channels.scm          the revisions every machine is built from
systems/
├── base.scm          what every machine has in common
├── template.scm      what a freshly cloned machine is
└── web01.scm         one machine
```

## How a machine ends up being itself

1. It boots from the generic image, built once from `systems/template.scm`.
2. [guix-metadata][metadata] reads the disk its host attached and writes
   `/etc/guix-gitops/runtime.scm`.
3. [guix-gitops][gitops] reads that file, fetches this repository, and
   reconfigures the machine to match the system file it names.
4. It keeps checking, and follows every commit from then on.

Telling a machine which one it is means one line, pasted into the host's user
data field:

```
#cloud-config
((system-file . "systems/web01.scm"))
```

[gitops]: https://github.com/prop4n/guix-gitops
[metadata]: https://github.com/prop4n/guix-metadata

## Adding a machine

Write `systems/<name>.scm`:

```scheme
(use-modules (systems base) (gnu) (gnu packages databases))

(homelab-operating-system
 #:host-name "db01"
 #:packages (list postgresql))
```

Commit, push, and point a machine at it. Nothing else to build.

## Building the generic image

```
guix system image -t qcow2 --image-size=20G \
  -L $PWD -L path/to/guix-gitops/modules -L path/to/guix-metadata/modules \
  systems/template.scm
```

Once, then import it as a template. It only needs rebuilding when the signing
key or the boot-time pieces change — not when a machine's configuration does.

## Updating everything

Refresh the pinned revisions and push:

```
guix describe -f channels > channels.scm
```

Every machine picks it up on its next cycle. That is how package updates and
security fixes reach the fleet.

## Signing

Machines refuse commits that are not signed by the key in
`.guix-authorizations`. Sign yours:

```
git config user.signingkey <FINGERPRINT>
git config commit.gpgsign true
```
