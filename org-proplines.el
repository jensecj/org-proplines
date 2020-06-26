;;; org-proplines.el --- Some description. -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Jens Christian Jensen

;; Author: Jens Christian Jensen <jensecj@gmail.com>
;; URL:
;; Keywords: org-mode
;; Package-Requires ((emacs "28.0.50"))
;; Package-Version: 20200626
;; Version: 0.1.0


;;; Commentary:
;;

;;; Code:

(defvar org-proplines-separator " "
  "")

(defvar org-proplines-entries
  '((:DATE . (lambda (d) (format "[%s]" d))))
  "")

(defun org-proplines--create-overlay (pos data)
  ""
  (let ((o (make-overlay pos pos (current-buffer) nil t)))
    (overlay-put o 'before-string data)
    (overlay-put o 'category 'org-proplines)))

(defun org-proplines--remove-overlays (&optional beg end)
  ""
  (save-excursion
    (widen)
    (dolist (o (overlays-in (or beg (point-min)) (or end (point-max))))
      (when (eq (overlay-get o 'category) 'org-proplines)
        (delete-overlay o)))))

(defun org-proplines--should-apply-p (&optional pos)
  ""
  (org-with-point-at (or pos (point))
    (and (eq major-mode 'org-mode)
         (not (org-invisible-p))
         (or (org-at-heading-p) (org-at-drawer-p) (org-at-property-p)))))

(defun org-proplines--map-visible-headings-in-region (fn beg end)
  ""
  (save-excursion
    (let ((top (window-start))
          (bot (window-end (selected-window) t)))
      (goto-char top)
      (while (< (point) bot)
        ;; maybe next-heading + pos-visible-in-window-p is faster?
        (org-next-visible-heading 1)
        (funcall fn)))))

(defun org-proplines-apply-to-element (e)
  ""
  (let* ((data (cadr e))
         (beg (plist-get data :begin))
         ;; :end in e is the end of the entire section, not the headline, so we grab it manually
         (end (save-excursion (goto-char beg) (line-end-position)))
         (level (plist-get data :level))
         (s))
    (org-proplines--remove-overlays beg end)
    (dolist (p org-proplines-entries)
      (when-let* ((prop (car p))
                  (fun (cdr p))
                  (content (plist-get data prop)))
        (push (ignore-errors (funcall fun content)) s)))
    (when s
      (org-proplines--create-overlay (+ beg level) (concat " " (string-join s org-proplines-separator))))))

(defun org-proplines-apply-at-point ()
  ""
  (interactive)
  (when (org-proplines--should-apply-p)
    (org-proplines-apply-to-element
     (org-with-point-at (org-entry-beginning-position)
       (org-element-at-point)))))

(defun org-proplines-apply-in-region (beg end)
  ""
  (when (org-proplines--should-apply-p beg)
    (save-mark-and-excursion
      (goto-char beg)
      (set-mark (point))
      (goto-char end)

      (org-proplines--map-visible-headings-in-region #'org-proplines-apply-at-point nil 'region))))

(defun org-proplines-apply-entire-buffer ()
  ""
  (interactive)
  (when (org-proplines--should-apply-p)
    (org-proplines--remove-overlays (window-start) (window-end))
    (org-proplines-apply-in-region (window-start) (window-end))))

(defun org-proplines--update-on-scroll (win beg)
  ""
  (when (org-proplines--should-apply-p)
    (let ((end (window-end (selected-window) t)))
      (org-proplines-apply-in-region beg end))))

;;;###autoload
(define-minor-mode org-proplines-mode
  ""
  nil " org-pl" nil
  (if org-proplines-mode
      (progn
        (org-proplines-apply-entire-buffer)
        (add-hook 'post-command-hook #'org-proplines-apply-at-point nil t)
        (add-hook 'after-save-hook #'org-proplines-apply-entire-buffer nil t)
        (make-variable-buffer-local 'window-scroll-functions)
        (add-to-list 'window-scroll-functions #'org-proplines--update-on-scroll)
        )
    (setq window-scroll-functions
          (delete #'org-proplines--update-on-scroll window-scroll-functions))
    (remove-hook 'post-command-hook #'org-proplines-apply-at-point t)
    (remove-hook 'after-save-hook #'org-proplines-apply-entire-buffer t)
    (jit-lock-unregister #'org-proplines-apply-in-region)
    (save-restriction
      (widen)
      (org-proplines--remove-overlays (point-min) (point-max)))))


(provide 'org-proplines)
;;; org-proplines.el ends here
