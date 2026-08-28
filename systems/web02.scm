;;; SPDX-License-Identifier: GPL-3.0-or-later

;; The same web server, with a page to serve.  The page lives in the store, so
;; changing it here is what changes what the machine serves -- there is no
;; step where anyone copies a file onto the machine.

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
<h1>web02</h1>
<p>Served by a machine that configured itself from Git.</p>
" port))))))

(homelab-operating-system
 #:host-name "web02"
 #:extra-services
 (list (service nginx-service-type
                (nginx-configuration
                 (server-blocks
                  (list (nginx-server-configuration
                         (listen '("80"))
                         (root %site))))))))
