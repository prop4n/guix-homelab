;;; SPDX-License-Identifier: GPL-3.0-or-later

;; What every machine here has in common.  A machine file loads this, then
;; adds what makes it itself.

(define-module (systems base)
  #:use-module (gnu)
  #:use-module (gnu system image)
  #:use-module (gitops services agent)
  #:use-module (metadata services nocloud)
  #:export (%homelab-introduction
            %homelab-services
            homelab-operating-system))

(use-service-modules base networking ssh)

;;; The channel instance, shipped rather than fetched.
;;;
;;; Without this, a machine's first reconfiguration begins by cloning
;;; guix.git -- hundreds of megabytes before it can evaluate anything.  Since
;;; channels.scm pins full commit hashes, Guix can name the instance it wants
;;; without asking the network: it hashes the commits, looks in its inferior
;;; cache, and stops there if it finds an entry.  So the entry is put in the
;;; image, and the instance comes with it.
;;;
;;; Both values below must be refreshed together whenever channels.scm moves:
;;;
;;;   guix time-machine -C channels.scm -- describe
;;;   readlink -f /var/guix/profiles/per-user/$USER/inferiors/<key>
;;;
;;; The key is the base32 SHA-256 of the pinned commits, concatenated in the
;;; order they appear in channels.scm.  A stale key is not fatal: the machine
;;; falls back to cloning.

(define %channel-instance-key
  "a642la7obo6hobkvl57qox6bdyq2ozbmksb4ywk4iyztejiyii7a")

(define %channel-instance
  "/gnu/store/jli0k2ad8raii54fs42qy07wygpkd7ld-profile")

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
  (append
   extra
   (list %inferior-cache-service

         (service dhcpcd-service-type)

         (service openssh-service-type
                  (openssh-configuration
                   (permit-root-login 'prohibit-password)
                   (password-authentication? #f)))

         ;; Runs once at boot: copies this host's user data into the file the
         ;; agent reads.  Harmless on a machine that has no datasource.
         (service nocloud-service-type)

         (service gitops-agent-service-type
                  (gitops-agent-configuration
                   (url "https://github.com/prop4n/guix-homelab.git")
                   (branch "main")
                   (system-file "systems/template.scm")
                   ;; Not optional: the machine files below use services from
                   ;; guix-gitops and guix-metadata, and the only way the
                   ;; agent's Guix knows those modules is by evaluating in an
                   ;; inferior built from these channels.  The price is that a
                   ;; fresh machine clones guix.git before its first
                   ;; reconfiguration.
                   (channels-file "channels.scm")
                   ;; The machine files here say (use-modules (systems base)),
                   ;; so the root of the checkout has to be on the load path.
                   (extra-load-path '("."))
                   (runtime-config-file "/etc/guix-gitops/runtime.scm")
                   (introduction %homelab-introduction)
                   (interval 900)
                   (health (gitops-health-configuration (port 9902))))))
   %base-services))

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
