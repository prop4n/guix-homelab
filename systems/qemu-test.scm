;;; SPDX-License-Identifier: GPL-3.0-or-later
;; Local QEMU test machine: DHCP networking (works with QEMU user-mode NAT),
;; plus a debug root password and ssh key.
(use-modules (systems base)
             (gnu)
             (guix gexp)
             (gnu packages admin)
             (gnu packages curl))
 ;; bump3

(homelab-operating-system
 #:host-name "qemu-test"
 #:packages (list (@ (gnu packages curl) curl))
 ;; bump3
 #:extra-services
 (list (simple-service 'debug-root-password activation-service-type
         #~(begin
             (use-modules (ice-9 popen))
             (let ((port (open-pipe* OPEN_WRITE
                                     #$(file-append shadow "/sbin/chpasswd"))))
               (display "root:debug\n" port)
               (close-pipe port))))
       (simple-service 'debug-root-ssh-key activation-service-type
         (with-imported-modules '((guix build utils))
           #~(begin
               (use-modules (guix build utils))
               (mkdir-p "/root/.ssh")
               (chmod "/root/.ssh" #o700)
               (call-with-output-file "/root/.ssh/authorized_keys"
                 (lambda (port)
                   (display "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNfWie5JNTDK1pj5OL8w/My5O8G4vA9BAw7vjyWwSF+ proxmops-debug\n" port)))
               (chmod "/root/.ssh/authorized_keys" #o600))))))
