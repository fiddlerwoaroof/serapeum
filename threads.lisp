(in-package #:serapeum)

;;; NB We use to use non-recursive locks here, but on comparison with
;;; other languages providing a `synchronized' keyword (Java,
;;; Objective-C, C#, D) they all use a recursive lock, so that is what
;;; we now use here.

(eval-when (:compile-toplevel :load-toplevel)
  (defconstant +lock-class+ (class-of (bt:make-recursive-lock))))

(defvar *monitors*
  (tg:make-weak-hash-table
   :weakness :key
   ;; This should be plenty big enough to never need resizing.
   :size 512))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun lock-form (object objectp env string)
    (cond ((not objectp)
           (let ((string (or string "Anonymous critical section")))
             `(load-time-value (bt:make-recursive-lock ,string))))
          ((constantp object env)
           `(load-time-value
             (ensure-monitor ,object ,string)))
          (t `(ensure-monitor ,object ,string)))))

(defmacro synchronized ((&optional (object nil objectp)) &body body &environment env)
  "Run BODY holding a unique lock associated with OBJECT.
If no OBJECT is provided, run BODY as an anonymous critical section.

If BODY begins with a literal string, attach the string to the lock
object created (as the argument to `bt:make-recursive-lock')."
  (multiple-value-bind (string? body)
      (if (stringp (first body))
          (values (first body) (rest body))
          (values nil body))
    (let* ((form (lock-form object objectp env string?)))
      (with-gensyms (lock)
        `(let ((,lock ,form))
           (bt:with-recursive-lock-held (,lock)
             ,@body))))))

(defgeneric monitor (object)
  (:documentation "Return a unique lock associated with OBJECT."))

(defmethod monitor ((object #.+lock-class+))
  object)

(defmethod monitor ((object t))
  nil)

(defun ensure-monitor (object string)
  (or (monitor object)
      (let ((string (or string "Monitor")))
        (flet ((ensure-monitor (object string)
                 (ensure-gethash object *monitors*
                                 (bt:make-recursive-lock string))))
          ;; Clozure has lock-free hash tables.
          #+ccl (ensure-monitor object string)
          #-ccl (synchronized ()
                  (ensure-monitor object string))))))

(defclass synchronized ()
  ((monitor :initform (bt:make-recursive-lock)
            :reader monitor))
  (:documentation "Mixin for a class with its own monitor."))
