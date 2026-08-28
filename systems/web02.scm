;;; SPDX-License-Identifier: GPL-3.0-or-later

;; A web server whose page is defined here.  nginx serves from a fixed path,
;; /srv/http, and an activation copies the page there on every reconfigure.
;; This matters: Guix does not restart a service whose definition changed, so
;; if nginx served straight from the store the page would only change on a
;; restart.  Serving from a fixed path that the activation refreshes means a
;; git push updates the page with no restart at all.

(use-modules (systems base)
             (gnu)
             (gnu services web)
             (guix gexp))

(define %site
  (computed-file
   "web02-site"
   #~(begin
       (mkdir #$output)
       (call-with-output-file (string-append #$output "/index.html")
         (lambda (port)
           (display "<!doctype html>
<title>web02</title>
<h1>web02 — version 3</h1>
<p>Cette page a change par un simple git push.</p>
" port))))))

(define %publish-site
  (simple-service
   'web02-content activation-service-type
   (with-imported-modules '((guix build utils))
     #~(begin
         (use-modules (guix build utils))
         (when (file-exists? "/srv/http")
           (delete-file-recursively "/srv/http"))
         (mkdir-p "/srv/http")
         (copy-recursively #$%site "/srv/http")
         (for-each (lambda (f) (chmod f #o644))
                   (find-files "/srv/http"))))))

(homelab-operating-system
 #:host-name "web02"
 #:extra-services
 (list %publish-site
       (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (root "/srv/http"))))))))
