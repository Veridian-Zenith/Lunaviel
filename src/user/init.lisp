;;; ============================================================================
;;; init.lisp — Lunaviel Core Userland Initialization
;;; ============================================================================
;;; Executes as the first userland-level task post-kernel handoff.
;;; Target: SBCL (bare-metal adapted or userspace sandbox testing)
;;; ============================================================================
;;; Author: Dae Euhwa
;;; License: AGPLv3 + VCL1.0
;;; ============================================================================

(format t "~%[Lunaviel Userland Bootstrapping...]~%")
(format t "[userland] Initializing runtime interfaces...~%")

(defvar *syscall-table* nil
  "Placeholder for syscall jump table or dispatch structure.")

(defvar *running* t
  "Controls main userland loop.")

(defun display-banner ()
  "Display an ASCII boot banner or welcome message."
  (format t "~%Lunaviel Core :: Userland Interface~%")
  (format t "--------------------------------------~%")
  (format t "Welcome, Dae. Everything's running smoothly.~%~%"))

(defun start-repl ()
  "Minimal command loop or diagnostic shell stub."
  (loop while *running* do
    (format t "lunaviel> ")
    (let ((input (read-line *standard-input* nil)))
      (cond
        ((or (null input) (string= input "exit"))
         (setf *running* nil)
         (format t "Exiting userland shell...~%"))
        ((string= input "help")
         (format t "Available commands: help, exit~%"))
        (t
         (format t "Unknown command: ~a~%" input))))))

(defun main ()
  "Primary userland entrypoint. Acts like init."
  (display-banner)
  (start-repl))

(main)
