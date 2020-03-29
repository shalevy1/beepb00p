(require 'org)
(require 'subr-x)
(require 's)
(require 'dash)

; TODO fucking hell, it doesn't seem capable of resolving symlinks

(setq   exobrain/rootdir    default-directory)
(defvar exobrain/input-dir  nil)
(defvar exobrain/public-dir nil)
(defvar exobrain/output-dir nil)


;; disable ~ files
(setq make-backup-files nil)

;; TODO share with compile-org?
(setq org-export-with-author nil)


;; examples of sitemap formatting
;; https://github.com/nanjj/nanjj.github.io/blob/4338fa60b07788885d3d4c8b2c684360a67e8098/org-publish.org


(defun my/org-publish-sitemap-entry (entry style project)
  ;; mdbook doesn't like list item not being a link
  ;; and default sitemap entry function explicitly ignores directories
  (if (directory-name-p entry)

      ;; README.md got some special handling, so we abuse that
      ;; https://rust-lang.github.io/mdBook/format/config.html?highlight=readme#configuring-preprocessors
      (format "[[file:%sREADME.org][%s]]" entry (directory-file-name entry))
      (org-publish-sitemap-default-entry entry style project)))


;; TODO ugh. not all timestamps are detected correctly??
;; TODO instead, map to dates only? check as well
(defun my-timestamp (timestamp _contents _info)
  "TS!!")

(require 'ox)
(require 'ox-org)
(require 'ox-md)

(org-export-define-derived-backend
 'my-org 'org
 :translate-alist
 '(
   (timestamp . my-timestamp)))


(defun org-org-publish-to-my-org (plist filename pub-dir)
  (org-publish-org-to 'my-org filename ".org" plist pub-dir))


;; https://orgmode.org/manual/Publishing-options.html#Publishing-options
;; TODO exclude-tags
;; with-author? with-timestamps? with-date?

(defun exobrain/extra-filter (output backend info)
  (check-output
   '("python3" "src/filter_org.py")
   :input output
   :cwd exobrain/rootdir))

(defun exobrain/md-org-make-tag-string (tags)
  (apply #'s-concat
   (-map
    (lambda (tag) (s-wrap tag "<span class='tag'>" "</span>"))
    tags)))


;; fucking hell, it's defsubst https://www.gnu.org/software/emacs/manual/html_node/elisp/Inline-Functions.html
;; that's why advice doesn't work
;; I hate elisp.
;; (advice-add #' org-element-property :around #'exobrain/md-org-element-property)

; (defun exobrain/org-md-headline (orig headline contents info)
;   (cl-letf (((symbol-function 'org-element-property) 'exobrain/md-org-element-property))
;     (funcall orig headline contents info)))


(defun exobrain/org-md-publish-to-md (orig-fun plist filename pub-dir)
  ;; fucking hell. I just hate elisp so much
  (cl-letf (((symbol-function 'org-make-tag-string) 'exobrain/md-org-make-tag-string))
    (funcall orig-fun plist filename pub-dir)))

(advice-add #'org-md-publish-to-md :around #'exobrain/org-md-publish-to-md)


(setq
 org-publish-project-alist
 `(("exobrain-inputs-public"
    :base-directory ,exobrain/input-dir
    :base-extension "org"
    :publishing-directory ,exobrain/public-dir
    :recursive t
    :publishing-function org-org-publish-to-my-org

    :auto-sitemap t
    :sitemap-format-entry my/org-publish-sitemap-entry
    :sitemap-filename "SUMMARY.org"

    ;; shit. only isolated timestamps work...
    ;; https://github.com/bzg/org-mode/blob/817c0c81e8f6d1dc387956c8c5b026ced62c157c/lisp/ox.el#L1896
    ;; :with-timestamps nil

    :with-date nil
    :with-properties nil
    :time-stamp-file nil

    ;; TODO not sure if should use final-output??
    :filter-body ,(cons #'exobrain/extra-filter org-export-filter-body-functions)
    ;; :filter-final-output ,(cons #'filt org-export-filter-final-output-functions)
    ;; TODO body??

    ;; :makeindex
    ;; :auto-index t
    ; :index-filename "sitemap.org"
    ; :index-title "Sitemap"

    :exclude "org.org") ;; TODO ??
   ("exobrain"
    :base-directory ,exobrain/public-dir
    :base-extension "org"
    :publishing-directory ,exobrain/output-dir
    :recursive t
    :publishing-function org-md-publish-to-md

    :with-tags          t
    :with-todo-keywords t
    :with-priority      t)))

    ; TODO????

; TODO shit. refuses to work.
(setq org-html-postamble-format "")


; TODO https://orgmode.org/worg/org-tutorials/org-publish-html-tutorial.html


;; TODO after intermediate, run santity check
