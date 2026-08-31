;;; SPDX-License-Identifier: GPL-3.0-or-later
;; Minimal debug machine: static IP .210, root ssh key + password, no nginx.
(use-modules (systems base)
             (gnu)
             (guix gexp)
             (gnu packages admin)
             (gnu services networking))

(homelab-operating-system
 #:host-name "debug"
 #:networking
 (list (service static-networking-service-type
                (list (static-networking
                       (addresses (list (network-address
                                         (device "eth0")
                                         (value "192.168.1.210/24"))))
                       (routes (list (network-route
                                      (destination "default")
                                      (gateway "192.168.1.1"))))
                       (name-servers '("1.1.1.1"))))))
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
                 (lambda (port) (display "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNfWie5JNTDK1pj5OL8w/My5O8G4vA9BAw7vjyWwSF+ proxmops-debug\n" port)))
               (chmod "/root/.ssh/authorized_keys" #o600))))))
