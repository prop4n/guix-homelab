;;; SPDX-License-Identifier: GPL-3.0-or-later

;; A web server running nginx with nothing to serve yet.

(use-modules (systems base)
             (gnu)
             (guix gexp)
             (gnu packages admin)
             (gnu services networking)
             (gnu services web))

(homelab-operating-system
 #:host-name "web-test3"
 #:networking
 (list (service static-networking-service-type
                (list (static-networking
                       (addresses
                        (list (network-address
                               (device "eth0")
                               (value "192.168.1.210/24"))))
                       (routes
                        (list (network-route
                               (destination "default")
                               (gateway "192.168.1.1"))))
                       (name-servers '("1.1.1.1"))))))
 #:extra-services
 (list ;; Debugging: set a known root password so the console login works.
       (simple-service 'debug-root-password activation-service-type
         #~(begin
             (use-modules (ice-9 popen))
             (let ((port (open-pipe* OPEN_WRITE
                                     #$(file-append shadow "/sbin/chpasswd"))))
               (display "root:debug\n" port)
               (close-pipe port))))
       ;; Debugging: authorise an ssh key for root (key-only login).
       (simple-service 'debug-root-ssh-key activation-service-type
         (with-imported-modules '((guix build utils))
           #~(begin
               (use-modules (guix build utils))
               (mkdir-p "/root/.ssh")
               (chmod "/root/.ssh" #o700)
               (call-with-output-file "/root/.ssh/authorized_keys"
                 (lambda (port)
                   (display "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNfWie5JNTDK1pj5OL8w/My5O8G4vA9BAw7vjyWwSF+ proxmops-debug\n"
                            port)))
               (chmod "/root/.ssh/authorized_keys" #o600))))
       (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (root "/srv/http"))))))))
