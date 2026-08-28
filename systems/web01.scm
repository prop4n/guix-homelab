;;; SPDX-License-Identifier: GPL-3.0-or-later

;; A web server running nginx with nothing to serve yet.

(use-modules (systems base)
             (gnu)
             (gnu services web))

(homelab-operating-system
 #:host-name "web01"
 #:extra-services
 (list (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (root "/srv/http"))))))))
