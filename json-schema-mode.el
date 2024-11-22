;;; json-schema-mode.el --- Schema validating mode for editing JSON/YAML -*- lexical-binding: t -*-

;; Copyright (C) 2023-2024, Holger Smolinski
;; SPDX-License-Identifier: GPL-3.0-only

;; Author: Holger Smolinski <json-emacs@smolinski.name>
;; Maintainer: Holger Smolinski <json-emacs@smolinski.name>
;; Version: 1.0
;; Date: 2023-11-07
;; Keywords: languages, javascript, json, yaml, json schema, 

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, version 3 of the License.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the GNU Lesser General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary

;; A schema validating mode for emacs editing JSON and YAML
;; provides:
;; - schema validation (via kwalify)

;; Exported names start with "json-schema-", "json-" or "yaml-".
;; Private names start with "json-schema--", "json--" or "yaml--".

;;; Code

(require 'prog-mode)

;;; Constants
(defconst json-schema-debug t)

;;; Configuration
(defvar json-schema-validator "kwalify" "The external validator program to run")
(defvar json-auto-validate t "Whether ot not to auto validate JSON on save")
(defvar yaml-auto-validate t "Whether ot not auto validate YAML on save")
(defvar json-schema-config-dir-pattern "^\.emacs\.d\$")
(defvar json-schema-config-file-pattern "schema\.config\$")

(defun debug-msg (&rest args)
  (if json-schema-debug
      (apply #'message args))
  )

(defun info-msg (&rest args)
  (apply #'message args)
  )

(defun fun-fail (&rest args)
  (apply #'message args)
  )

(debug-msg "schema variable %s %s" json-schema-config-dir-pattern json-schema-config-file-pattern)

;;
;; @function: realfile
;; returns the realfile after resolving all symlinks
(defun realfile (file)
  (cond ((and (file-regular-p file) (file-readable-p file)) file)
	((file-symlink-p file) (realfile (file-symlink-p file)))
        (t nil))
  )

;;
;; @function: parent-directory
;; returns the parent directory of a node (file or directory)
;; @param [in]: a file system node
;; @param [out]: a directory node or nil
(defun parent-directory (thisnode)
  (unless (equal "/" thisnode)
    (let ((parent-node (file-name-directory (directory-file-name thisnode))))
      (if (file-readable-p parent-node)
	  parent-node
        nil)))
  )


;; @function: run-command-to-buffer
(defun run-command-to-buffer (cmd outbuf &rest cmd-args)
  "Run CMD on the BUFFER with optional CMD-ARGS."
  (debug-msg "running '%s' to buffer '%s' with args '%s'" cmd outbuf cmd-args)
  (when cmd
    (save-mark-and-excursion
      (eval
       (append (list 'call-process cmd nil (get-buffer-create outbuf) t) cmd-args))))
  )

(defun json-schema--validate-file (file schema)
  (if (file-readable-p schema)
      (if (file-readable-p file)
          (progn
            (run-command-to-buffer json-schema-validator "*SCHEMA*" "-E" "-f" schema file)
            )
        (fun_fail "File is not readable: %s" file))
    (fun_fail "Schema is not readable: %s" schema))
  )

(defun json-schema-check-validator ()
  (run-command-to-buffer json-schema-validator nil "-v")
  )

;; @function: collect-directories-by-pattern
(defun collect-directories-by-pattern (dir pattern)
  (debug-msg "collect-directories-by-pattern: %s %s" dir pattern)
  (if (file-directory-p dir)
      (let ((dirlist (append (mapcan
			      (lambda (d)
                                "return the directories in dir's content matching the pattern"
                                (when (file-directory-p d)
                                  (list d)))
			      (directory-files dir t pattern))
			     (let ((parent-dir (parent-directory dir)))
			       (unless (eq parent-dir nil)
				 (collect-directories-by-pattern parent-dir pattern))))))
	(info-msg "Found directories: %s" dirlist)
	dirlist)
    (fun-fail  "%s is not a directory" dir)
    )
  )

;; @function: collect-files-by-pattern
(defun collect-files-by-pattern (dirlist pattern)
  (debug-msg "collect-files-by pattern %s %s" dirlist pattern)
  (let ((filelist (mapcan (lambda (dir)
			    (let ((match (mapcan
					  (lambda (entry)
					    (if (file-readable-p entry)
						(list entry)
					      ))
					  (directory-files dir t pattern))))
			      (debug-msg "Match in %s: %s" dir match)
			      match))
			  dirlist)))
    (info-msg "Found files: %s" filelist)
    filelist
    )
  )

;; @function: json-schema-config-files
(defun json-schema-config-files (file)
  (let ((config-files
         (collect-files-by-pattern
          (collect-directories-by-pattern
           (file-name-directory file)
           json-schema-config-dir-pattern)
          json-schema-config-file-pattern)))
    (info-msg "JSON schema config files: \n%s\n" config-files)
    config-files
    )
  )

(defun unwrap-list-of-lists (lstlst)
  (if lstlst
      (append (car lstlst) (unwrap-list-of-lists (cdr lstlst)))
    )
  )

;;
;; interactive commands
;;
(defun json-schema-validate-buffer (&optional validation-buffer)
  "Validate buffer holding JSON/YAML against all applicable JSON schemata."
  (interactive)
  ;; First check the pre-requisites
  (let ((buffer (if validation-buffer validation-buffer (current-buffer))))
    (let ((file (buffer-file-name buffer)))
      (if file
          (mapcan (lambda (schema) ;; validate file against schema
                    (json-schema--validate-file file schema))
                  (mapcan (lambda (cstr) ;; match filename pattern vs. filename
                            (progn
;;                              (debug-msg "check cstr %s" cstr)
                            (cond ((string-match-p (car cstr) file) (cdr cstr))
                                  (t nil))))
		          (unwrap-list-of-lists
                           (mapcan (lambda (cfg) ;; extract "schema-patterns" elements
                                     (progn
  ;;                                     (debug-msg "Extracting schema pattern from %s" cfg)
                                        (cond ((string-equal (car cfg) "schema-patterns") (cdr cfg))
                                              (t nil))))
			           (mapcan (lambda (file) ;; eval config file as list
                                             (with-temp-buffer
                                               (progn
    ;;                                             (debug-msg "evaluating config file %s" file)
                                                 (insert-file-contents file)
                                                 (list (read (buffer-string)))
                                                 )))
                                           ;;  all config files
				           (json-schema-config-files file))))))
        (fun-fail "Buffer %s is not holding a file." buffer)
        )
      (debug-msg "Buffer validation running on file %s" file))
    ))

(defun toggle-json-auto-validate ()
  "Toggles json file atomatic validation."
  (interactive)
  (if json-auto-validate
      (setq json-auto-validate nil)
    (setq json-auto-validate t)
    )
  (debug-msg"JSON Auto Validation : %s" json-auto-validate )
  )

(defun toggle-yaml-auto-validate ()
  "Toggles yaml file atomatic validation."
  (interactive)
  (if yaml-auto-validate
      (setq yaml-auto-validate nil)
    (setq yaml-auto-validate t)
    )
  (debug-msg"YAML Auto Validation : %s" yaml-auto-validate )
  )

(defvar json-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\s " " st) ;; space
    (modify-syntax-entry ?\t " " st) ;; tab
    (modify-syntax-entry ?\n " " st) ;; newline
    (modify-syntax-entry ?{ "(}" st) ;; open brace
    (modify-syntax-entry ?} "){" st) ;; close brace
    (modify-syntax-entry ?[ "(]" st) ;; open brace
    (modify-syntax-entry ?] ")[" st) ;; close brace
    (modify-syntax-entry ?\" "\"" st) ;; 
    (modify-syntax-entry ?: "." st) ;; colon
    (modify-syntax-entry ?, "." st) ;; comma
    st)
  "Syntax table for `json-mode'."
  )

(defvar json-mode-map
  (let ((map (make-sparse-keymap)))
    (easy-menu-define nil map "JSON Schema"
      '("Schema-Validate"
        ["Validate buffer" json-schema-validate-buffer t]
        ["Settings" nil
         (fboundp #'inferior-moz-process)]))
    (message "Establishing schema validate keymap")
    map)
  "Keymap for `json-mode'."
  )

(defvar yaml-mode-map
  json-mode-map
  "Keymap for `yaml-mode'."
  )

(define-derived-mode json-mode javascript-mode "JavaScript/JSON"
  "Schema validating mode as default mode for editing JSON."
  :group 'js
  :syntax-table nil
  ;; (json-mode-syntax-table)
  ;; (json-mode-map)
  (setq-default indent-tabs-mode nil)
  (setq-local comment-start nil)
  (setq-local comment-end "")
  (json-schema-auto-validate-mode)
  (when json-auto-validate
    (add-hook 'after-save-hook 'json-schema-validate-buffer nil)
    (message "Auto validation enabled"))
  (message "Entering JSON mode")
  )

(define-derived-mode yaml-mode prog-mode "YAML"
  "Schema validating mode for YAML"
  :group 'js
  :syntax-table nil
  (setq-default indent-tabs-mode nil)
  (setq-local comment-start nil)
  (setq-local comment-end "")
  (yaml-schema-auto-validate-mode)
  (when yaml-auto-validate
    (add-hook 'after-save-hook 'json-schema-validate-buffer nil)
    (message "Auto validation enabled"))
  (message "Entering YAML mode")
  )

(define-minor-mode json-schema-auto-validate-mode
  "Minor mode for automatic schema validation of JSON documents."
  :initial-value (when (derived-mode-p 'json-mode)
		   (if (json-schema-check-validator)
		       json-auto-validate
		     nil))
  :lighter " auto-validate"
  )

(define-minor-mode yaml-schema-auto-validate-mode
  "Minor mode for automatic schema validation of YAML documents."
  :initial-value (when (derived-mode-p 'yaml-mode)
                   (if (json-schema-check-validator)
		       yaml-auto-validate
                     nil))
  :lighter " auto-validate"
  )

;; here we go...
(if (not  (memq '(".*\\.json$" . json-mode) auto-mode-alist ))
    (add-to-list 'auto-mode-alist '(".*\\.json$" . json-mode))
  (message "JSON mode already on auto mode list")
  )
(if (not (memq '(".*\\.yaml$" . yaml-mode) auto-mode-alist ))
    (add-to-list 'auto-mode-alist '(".*\\.yaml$" . yaml-mode))
  (message "YAML mode already on auto mode list")
  )
(message "Loaded schema validate modes")

(provide 'json-schema-mode)
(provide 'json-mode)
(provide 'yaml-mode)
;;; json-schema-mode.el ends here
