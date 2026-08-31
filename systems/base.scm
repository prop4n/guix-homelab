;;; SPDX-License-Identifier: GPL-3.0-or-later

;; What every machine here has in common.  A machine file loads this, then
;; adds what makes it itself.
;;
;; The agent evaluates these files with the Guix baked into the image, not
;; with an inferior it has to build first.  That is why the guix-gitops and
;; guix-metadata modules are vendored under ./modules and put on the load path
;; below: a machine reconfigures in seconds, at first boot and on every commit.
;;
;; The trade-off: a machine runs the package versions of the image's Guix.  To
;; move to newer packages, rebuild the image -- not something a commit does.
;;
;; Vendored:
;;   modules/gitops   from guix-gitops   236a7a7
;;   modules/metadata from guix-metadata b9aadab
;; Refresh them by copying the modules/ trees from those repositories.

(define-module (systems base)
  #:use-module (gnu)
  #:use-module (gnu system image)
  #:use-module (gitops services agent)
  #:use-module (guix channels)
  #:use-module (metadata services nocloud)
  #:export (%homelab-channels
            %homelab-introduction
            %homelab-services
            homelab-operating-system))

(use-service-modules base networking ssh)

(define %homelab-channels
  ;; Given to the guix service below, which installs it as
  ;; /etc/guix/channels.scm so the machine's own 'guix pull' sees the same
  ;; channels -- and the substitute servers make it fast.
  (list (channel
         (name 'guix)
         (url "https://git.guix.gnu.org/guix.git")
         (branch "master")
         (introduction
          (make-channel-introduction
           "9edb3f66fd807b096b48283debdcddccfea34bad"
           (openpgp-fingerprint
            "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
        (channel
         (name 'nonguix)
         (url "https://gitlab.com/nonguix/nonguix")
         (branch "master")
         (introduction
          (make-channel-introduction
           "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
           (openpgp-fingerprint
            "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))))

(define %homelab-introduction
  ;; Every machine refuses commits that are not signed by this key, wherever
  ;; it is told to look.  It is declared here rather than injected at boot so
  ;; that whoever writes a machine's runtime file cannot weaken it.
  (gitops-introduction
   (commit "4a72fc42b3e6b879d8664dc980c2843a99494349")
   (signer "90C8 D92A 6D65 856C 0F84  EAE2 7E1F FB95 9BB3 3640")))

(define* (%homelab-services #:key (extra '())
                            (networking (list (service dhcpcd-service-type))))
  "Return the services every machine runs: the agent that keeps it in sync,
the reader that tells it which machine it is, and enough to reach the network.
NETWORKING defaults to DHCP; a machine may pass a static-networking service
instead."
  (modify-services
      (append
       extra
       networking
       (list (service openssh-service-type
                      (openssh-configuration
                       (permit-root-login 'prohibit-password)
                       (password-authentication? #f)))

             ;; Runs once at boot: copies this host's user data into the file
             ;; the agent reads.  Harmless without a datasource.
             (service nocloud-service-type)

             (service gitops-agent-service-type
                      (gitops-agent-configuration
                       (url "https://github.com/prop4n/guix-homelab.git")
                       (branch "main")
                       (system-file "systems/template.scm")
                       ;; "." makes (systems base) resolvable, "modules" makes
                       ;; the vendored gitops and metadata modules resolvable.
                       ;; No channels-file: the image's Guix is used directly.
                       (extra-load-path '("." "modules"))
                       (runtime-config-file "/etc/guix-gitops/runtime.scm")
                       (introduction %homelab-introduction)
                       (interval 60)
                       ;; Machines deliberately run the Guix baked into the image
                       ;; (updated by rebuilding the image, not by a commit).  After
                       ;; a reboot the running generation records that Guix as its
                       ;; provenance, so the next reconfigure -- still using the
                       ;; image's Guix -- looks like a channel downgrade and 'guix
                       ;; system' aborts.  Allowing it is the intended behaviour here.
                       (allow-downgrades? #t)
                       (log-file "/dev/console")
                       ;; Bind on all interfaces so the agent's state (applied,
                       ;; observed, failed, up-to-date) is readable from the LAN --
                       ;; a reliable window into what a machine is doing, unlike the
                       ;; serial console.  Exposes commit hashes and status only.
                       (health (gitops-health-configuration
                                (host "0.0.0.0")
                                (port 9902))))))
       %base-services)

    (guix-service-type
     config => (guix-configuration
                (inherit config)
                ;; Install channels.scm through the guix service itself, not a
                ;; separate etc entry: doing it separately turns /etc/guix into
                ;; a read-only store symlink, and the service can then no longer
                ;; write the substitute ACL there -- which silently disables
                ;; every substitute and turns each reconfigure into a
                ;; from-source rebuild.
                (channels %homelab-channels)
                (substitute-urls
                 (append (list "https://substitutes.nonguix.org")
                         %default-substitute-urls))
                (authorized-keys
                 (append (list (local-file "../signing-key.pub"))
                         %default-authorized-guix-keys))))))

(define* (homelab-operating-system #:key host-name (extra-services '())
                                   (packages '())
                                   (networking (list (service dhcpcd-service-type))))
  "Return an operating system for a virtual machine in this homelab.
NETWORKING defaults to DHCP; pass a static-networking service for a fixed address."
  (operating-system
    (host-name host-name)
    (timezone "Europe/Paris")
    (locale "fr_FR.utf8")

    (bootloader
     (bootloader-configuration
      (bootloader grub-bootloader)
      (targets '("/dev/vda"))
      (terminal-outputs '(console))))

    (kernel-arguments '("console=ttyS0,115200"))

    (file-systems
     (cons (file-system
             (mount-point "/")
             (device (file-system-label root-label))
             (type "ext4"))
           %base-file-systems))

    (packages (append packages %base-packages))

    (services (%homelab-services #:extra extra-services
                                 #:networking networking))))
