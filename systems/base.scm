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

(define %homelab-introduction
  ;; Every machine refuses commits that are not signed by this key, wherever
  ;; it is told to look.  It is declared here rather than injected at boot so
  ;; that whoever writes a machine's runtime file cannot weaken it.
  (gitops-introduction
   (commit "REPLACE-WITH-THE-FIRST-SIGNED-COMMIT-OF-THIS-REPOSITORY")
   (signer "90C8 D92A 6D65 856C 0F84  EAE2 7E1F FB95 9BB3 3640")))

(define* (%homelab-services #:key (extra '()))
  "Return the services every machine runs: the agent that keeps it in sync,
the reader that tells it which machine it is, and enough to reach the network."
  (append
   extra
   (list (service dhcpcd-service-type)

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
                   (channels-file "channels.scm")
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
