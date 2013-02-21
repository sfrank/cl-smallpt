;;; -*- Mode: LISP; Syntax: COMMON-LISP -*-

(defpackage #:smallpt-config (:export #:*base-directory*))
(defparameter smallpt-config:*base-directory* 
  (make-pathname :name nil :type nil :defaults *load-truename*))

(defpackage :smallpt-system (:use :asdf :cl))
(in-package :smallpt-system)

(defsystem :cl-smallpt
  :name "cl-smallpt"
  :description "Smallpt in Common Lisp"
  :serial t
  :components
  ((:module smallpt
    :pathname ""
    :components ((:file "smallpt")
                 )))
  :depends-on
  (:lparallel))
