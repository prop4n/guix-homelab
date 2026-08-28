;;; SPDX-License-Identifier: GPL-3.0-or-later

;; web02 now runs a real stateful application: Miniflux, a feed reader, backed
;; by PostgreSQL.  Miniflux listens on localhost:8080; nginx sits in front on
;; port 80 and proxies to it.  Deploying all of this -- database, roles,
;; migrations, the app, the reverse proxy -- is what a single git push does.

(use-modules (systems base)
             (gnu)
             (gnu packages databases)
             (gnu services databases)
             (gnu services web))

(homelab-operating-system
 #:host-name "web02"
 #:extra-services
 (list (service postgresql-service-type
                (postgresql-configuration
                 (postgresql postgresql)))
       (service postgresql-role-service-type)

       (service miniflux-service-type
                (miniflux-configuration
                 (listen-address "127.0.0.1:8080")
                 (base-url "http://localhost/")
                 (create-administrator-account? #t)
                 (administrator-account-name "admin")
                 (administrator-account-password "miniflux123")))

       (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (locations
                          (list (nginx-location-configuration
                                 (uri "/")
                                 (body
                                  (list "proxy_pass http://127.0.0.1:8080;"
                                        "proxy_set_header Host $host;"
                                        "proxy_set_header X-Forwarded-For $remote_addr;"
                                        "proxy_set_header X-Forwarded-Proto $scheme;"))))))))))))
