;;; SPDX-License-Identifier: GPL-3.0-or-later

(use-modules (systems base)
             (gnu)
             (gnu packages web))

(homelab-operating-system
 #:host-name "web01"
 #:packages (list nginx))
