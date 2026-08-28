;;; SPDX-License-Identifier: GPL-3.0-or-later

;; What every machine here has in common.  A machine file loads this, then
;; adds what makes it itself.

(define-module (systems base)
  #:use-module (gnu)
  #:use-module (gnu system image)
  #:use-module (gitops services agent)
  #:use-module (guix gexp)
  #:use-module (metadata services nocloud)
  #:export (%homelab-channels
            %homelab-introduction
            %homelab-services
            homelab-operating-system))

(use-service-modules base networking ssh)

(define %homelab-channels
  ;; Installed as /etc/guix/channels.scm, so the machine's own 'guix pull'
  ;; sees the same channels its configuration is written against.
  (plain-file "channels.scm" "\
(list (channel
       (name 'guix)
       (url \"https://git.guix.gnu.org/guix.git\")
       (branch \"master\")
       (introduction
        (make-channel-introduction
         \"9edb3f66fd807b096b48283debdcddccfea34bad\"
         (openpgp-fingerprint
          \"BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA\"))))

      (channel
       (name 'nonguix)
       (url \"https://gitlab.com/nonguix/nonguix\")
       (branch \"master\")
       (introduction
        (make-channel-introduction
         \"897c1a470da759236cc11798f4e0a5f7d4d59fbc\"
         (openpgp-fingerprint
          \"2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5\")))))
"))

;;; The channel instance, shipped rather than rebuilt.
;;;
;;; Substitute servers do not help here: this instance is composed of guix
;;; plus two channels nobody else builds, so no substitute for it exists and a
;;; fresh machine would compile the whole of Guix before its first
;;; reconfiguration.  Since channels.scm pins full commit hashes, Guix can
;;; name the instance it wants without asking the network -- it hashes the
;;; commits and looks in its inferior cache.  So the entry is put in the image.
;;;
;;; Both values must be refreshed together whenever channels.scm moves:
;;;
;;;   guix time-machine -C channels.scm -- describe
;;;   readlink -f /var/guix/profiles/per-user/$USER/inferiors/<key>
;;;
;;; The key is the base32 SHA-256 of the pinned commits concatenated in the
;;; order they appear in channels.scm.  A stale key is not fatal: the machine
;;; falls back to building the instance itself, slowly.

(define %channel-instance-key
  "hw7crto7ueoucbehu5qmcwll4onvpswdyrndbczjklv75k2g5una")

(define %channel-instance
  "/gnu/store/884hdc9j3568rg4cx0rz9wv7dr7rrg7d-profile")

(define %inferior-cache-service
  (simple-service
   'gitops-inferior-cache activation-service-type
   #~(let* ((directory "/var/guix/profiles/per-user/root/inferiors")
            (entry (string-append directory "/" #$%channel-instance-key)))
       (mkdir-p directory)
       (unless (file-exists? entry)
         (symlink #$%channel-instance entry)))))

(define %homelab-introduction
  ;; Every machine refuses commits that are not signed by this key, wherever
  ;; it is told to look.  It is declared here rather than injected at boot so
  ;; that whoever writes a machine's runtime file cannot weaken it.
  (gitops-introduction
   (commit "4a72fc42b3e6b879d8664dc980c2843a99494349")
   (signer "90C8 D92A 6D65 856C 0F84  EAE2 7E1F FB95 9BB3 3640")))

(define* (%homelab-services #:key (extra '()))
  "Return the services every machine runs: the agent that keeps it in sync,
the reader that tells it which machine it is, and enough to reach the network."
  (modify-services
      (append
       extra
       (list %inferior-cache-service

             (service dhcpcd-service-type)

             (service openssh-service-type
                      (openssh-configuration
                       (permit-root-login 'prohibit-password)
                       (password-authentication? #f)))

             (simple-service 'homelab-channels etc-service-type
                             (list `("guix/channels.scm" ,%homelab-channels)))

             ;; Runs once at boot: copies this host's user data into the file
             ;; the agent reads.  Harmless without a datasource.
             (service nocloud-service-type)

             (service gitops-agent-service-type
                      (gitops-agent-configuration
                       (url "https://github.com/prop4n/guix-homelab.git")
                       (branch "main")
                       (system-file "systems/template.scm")
                       (channels-file "channels.scm")
                       ;; The machine files say (use-modules (systems base)),
                       ;; so the root of the checkout goes on the load path.
                       (extra-load-path '("."))
                       (runtime-config-file "/etc/guix-gitops/runtime.scm")
                       (introduction %homelab-introduction)
                       (interval 900)
                       (health (gitops-health-configuration (port 9902))))))
       %base-services)

    (guix-service-type
     config => (guix-configuration
                (inherit config)
                (substitute-urls
                 (append (list "https://substitutes.nonguix.org")
                         %default-substitute-urls))
                (authorized-keys
                 (append (list (local-file "../signing-key.pub"))
                         %default-authorized-guix-keys))))))

(define* (homelab-operating-system #:key host-name (extra-services '())
                                   (packages '()))
  "Return an operating system for a virtual machine in this homelab."
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

    (services (%homelab-services #:extra extra-services))))
