;;; ob-sparql.el --- org-babel functions for SPARQL queries

;; Copyright (C) 2014, 2015 Bjarte Johansen
;; Copyright (C) 2015       Alf Lervåg

;; Author: Bjarte Johansen
;; Keywords: literate programming, reproducible research
;; Homepage: http://www.github.com/ljos/sparql-mode
;; Version: 0.0.2

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with SPARQL mode. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides a way to evaluate SPARQL queries in org-mode.

;;; Usage:

;; Add to your Emacs config:

;; (org-babel-do-load-languages
;;  'org-babel-load-languages
;;  '((sparql . t)))

;;; Code:
(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'sparql-mode)

(defvar org-babel-default-header-args:sparql
  `((:url . ,sparql-default-base-url)
    (:format . ,sparql-default-format))
  "Default arguments for evaluating a SPARQL query
block.")

(defun org-babel-execute:sparql (body params)
  "Execute a block containing a SPARQL query with
org-babel.  This function is called by
`org-babel-execute-src-block'. If `es-warn-on-delete-query' is
set to true, this function will also ask if the user really wants
to do that."
  (message "Executing a SPARQL query block.")
  (let* ((full-body (org-babel-expand-body:sparql body params))
         (endpoint-url (cdr (assoc :url params)))
         (url-request-method "POST")
         (url-mime-accept-string (cdr (assoc :format params)))
         (url-request-data (format "query=%s" (url-hexify-string full-body)))
         (url-request-extra-headers
          `(("Content-Type" . "application/x-www-form-urlencoded"))))
    (with-current-buffer (url-retrieve-synchronously endpoint-url)
      (if (zerop (buffer-size))
          (error "URL '%s' is not accessible" endpoint-url)
        (goto-char (point-min))
        (let ((result-is-csv (string-equal "text/csv" url-mime-accept-string))
              (query-failed (not (string-match "^.* 200 OK$" (thing-at-point 'line)))))
          (if query-failed
              (buffer-string)
            (search-forward "\n\n")
            (delete-region (point-min) (point))
            (org-babel-result-cond (cdr (assoc :result-params params))
              (buffer-string)
              (if result-is-csv
                  (org-babel-sparql-convert-to-table)
                (buffer-string)))))))))

(defun org-babel-sparql-convert-to-table ()
  "Convert the results buffer to an org-table."
  (org-table-convert-region (point-min) (point-max) '(4))
  (let ((table (org-table-to-lisp)))
    (cons (car table) (cons 'hline (cdr table)))))

(defun org-babel-expand-body:sparql (body params)
  "Expand BODY according to PARAMS, returning expanded body.
A variable is marked by the use of '?' or '$'; the marker is not part of
the variable name, thus '?x' and '$x' refer to the same variable."
  (reduce (lambda (acc pair)
            (replace-regexp-in-string
             (concat "[$?]" (regexp-quote (format "%s" (car pair)))) (cdr pair) acc))
          (mapcar #'cdr (org-babel-get-header params :var))
          :initial-value body))

(provide 'ob-sparql)
;;; ob-sparql.el ends here
