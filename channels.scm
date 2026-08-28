;;; SPDX-License-Identifier: GPL-3.0-or-later

;; The revisions every machine in this repository is built from.  Bumping a
;; commit here is how a machine gets updated: the agent evaluates its system
;; file with exactly these, and nothing else.
;;
;; Refresh them with:  guix describe -f channels

(list (channel
       (name 'guix)
       ;; The same mirror this workstation pulls from.  git.savannah.gnu.org
       ;; refused the connection outright from a virtual machine.
       (url "https://git.guix.gnu.org/guix.git")
       (branch "master")
       (commit "e5186f7bd43e5a12228ffd9b058fd346a4a94ba1")
       (introduction
        (make-channel-introduction
         "9edb3f66fd807b096b48283debdcddccfea34bad"
         (openpgp-fingerprint
          "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))

      (channel
       (name 'guix-gitops)
       (url "https://github.com/prop4n/guix-gitops.git")
       (branch "main")
       (commit "236a7a78cf913528569cfc854dafd8b81f359569")
       (introduction
        (make-channel-introduction
         "09fc5082f184bdecde93dfa742bedf5ff8c587ac"
         (openpgp-fingerprint
          "90C8 D92A 6D65 856C 0F84  EAE2 7E1F FB95 9BB3 3640"))))

      (channel
       (name 'guix-metadata)
       (url "https://github.com/prop4n/guix-metadata.git")
       (branch "main")
       (commit "b9aadabd5384198545d7c6f44398de50108d61b5")
       (introduction
        (make-channel-introduction
         "1afe33a9aa19a74773ca8fee2dad7286196ce7ff"
         (openpgp-fingerprint
          "90C8 D92A 6D65 856C 0F84  EAE2 7E1F FB95 9BB3 3640")))))
