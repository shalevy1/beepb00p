;; disable paredit so it doesn't mess with formatting


;; require it straightaway so we don't need with-eval-after-load
(require 'org)

;; TODO ok, so maybe do not export CREATED property, but show it as a tooltip?
;; TODO hmm. find another way to configure these...
;; TODO use STRT?
(setq org-todo-keywords '((sequence "TODO" "STRT" "START" "DONE")))

;; default references are some sort of hashes, which is very confusing when you are trying to track changes
;; TODO shit, quadratic time! perhaps start with max??
(defun org-export-deterministic-reference (references)
  (let ((new 0))
    (while (rassq new references) (setq new (+ new 1)))
    new))
(advice-add #'org-export-new-reference :override #'org-export-deterministic-reference)


(setq org-time-stamp-custom-formats
      '("[%Y-%m-%d]" . "[%Y-%m-%d %H:%M]"))

(setq org-display-custom-times 't)

; TODO give tags different colors depending on whether it actually exists or not?
(defun org-blog-tag (path desc fmt)
   (format "<a class='post-tag' href='./tags.html#%s'>#%s</a>" path path)
)
(org-add-link-type "tag" nil 'org-blog-tag)

(defun org-blog-sidenote (path desc fmt)
; TODO ugh. can't nest link inside the sidenote content??
; and writing that on elisp is gonna suck. really need python exporting backend...
; (message (format "HELLOO  =================== %s" desc))
   (format "<aside class='sidenote'>%s</aside>" desc)
)
(org-add-link-type "sidenote" nil 'org-blog-sidenote)
; TODO instead, use some sort of project wise config?

(setq org-export-global-macros '(
            ("aside"  . "@@html:<aside>@@$0@@html:</aside>@@")
            ("anchor" . "@@html:<a name='$0'></a>@@")
))

(setq org-export-with-author nil)

; https://github.com/gongzhitaao/orgcss#code-highlight
(setq org-html-htmlize-output-type 'css)


(require 'subr-x) ; ugh, for string-join...
(with-eval-after-load 'org
            ; treat mypy highlight as python. see org-html-fontify-code
            (add-to-list 'org-src-lang-modes '("mypy" . python))
            (load-file "~/dotfiles-emacs/babel-mypy.el")

            ; necessary so it doesn't prompt us
            (setq org-confirm-babel-evaluate nil)

            (setq org-babel-python-command "python3")

; TODO eh, it's a bit shit..
(defun org-babel-exp-code (info type)
  "Return the original code block formatted for export."
  (setf (nth 1 info)
	(if (string= "strip-export" (cdr (assq :noweb (nth 2 info))))
	    (replace-regexp-in-string
	     (concat (org-babel-noweb-wrap) "\n") "" (nth 1 info))
	  (if (org-babel-noweb-p (nth 2 info) :export)
	      (org-babel-expand-noweb-references
	       info org-babel-exp-reference-buffer)
	    (nth 1 info))))
  (org-fill-template
   (if (eq type 'inline)
       org-babel-exp-inline-code-template
       org-babel-exp-code-template)
   `(("lang"  . ,(nth 0 info))
     ("body"  . ,(org-escape-code-in-string (nth 1 info)))
     ("switches" . ,(let ((f (nth 3 info)))
		      (and (org-string-nw-p f) (concat " " f))))
     ("flags" . ,(let ((f (assq :flags (nth 2 info))))
		   (and f (concat " " (cdr f)))))
     ,@(mapcar (lambda (pair)
		 (cons (substring (symbol-name (car pair)) 1)
		       (format "%S" (cdr pair))))
	       (nth 2 info))
     ("name"  . ,(or (nth 4 info) "")))))

            ; (setq org-babel-noweb-wrap-end ">>\n")
            )

; TODO not sure..
; (with-eval-after-load 'python
;             (setq python-indent-guess-indent-offset nil))


; TODO ugh. could be a good idea to write about it. otherwise,
; org-babel-exp-results ignores it on line:
;      (when (fboundp (intern (concat "org-babel-execute:" lang)))
; TODO perhaps good idea at least to sugggest to emit a warning?
(require 'ob-python)


;; t is for BODY-ONLY
(org-html-export-as-html nil nil nil t)

;; NOTE: python format pattern
(write-file "{out_html}")
