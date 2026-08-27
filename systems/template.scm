;;; SPDX-License-Identifier: GPL-3.0-or-later

;; The machine a freshly cloned virtual machine is until it is told otherwise.
;; This is what the generic image is built from, and what a machine falls back
;; to when no runtime configuration reached it.

(use-modules (systems base))

(homelab-operating-system
 #:host-name "homelab-template")
