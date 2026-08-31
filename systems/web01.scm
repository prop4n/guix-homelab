;;; SPDX-License-Identifier: GPL-3.0-or-later

;; A web server running nginx with nothing to serve yet.

(use-modules (systems base)
             (gnu)
             (gnu services networking)
             (gnu services web))

(homelab-operating-system
 #:host-name "web01-pinned"
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
 (list (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (root "/srv/http"))))))))
