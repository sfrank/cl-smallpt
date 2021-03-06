;;; -*- Mode: LISP; Syntax: COMMON-LISP; Base: 10 -*-

(in-package :cl-user)

(defpackage :smallpt
  (:documentation "Simple path tracer")
  (:use :cl)
  ;(:export
  ; )
  )

(in-package :smallpt)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +xsize+ 1024)
  (defconstant +ysize+ 768)
  )

(declaim (inline power))

(defun power (base power)
  (expt base power))

(define-compiler-macro power (&whole whole base power &environment env)
  (if (integerp power)
      (labels ((build-expr (n last-var alist)
                 (if (= n power)
                     last-var
                     (let* ((alist (acons n last-var alist))
                            (other (assoc-if (lambda (y)
                                               (<= (+ y n) power))
                                             alist))
                            (nm (+ n (car other)))
                            (x^y (make-symbol (format nil "X^~A" nm))))
                       `(let ((,x^y (* ,last-var ,(cdr other))))
                          ,(build-expr nm x^y alist))))))
        (let ((form (let ((positive-expt-expr (build-expr 1 'x nil)))
                      (if (plusp power)
                          positive-expt-expr
                          `(/ ,positive-expt-expr))))
              (real-base (macroexpand base env)))
          (if (atom real-base)
              (subst base 'x form)
              `(let ((x ,base)) ,form))))
      whole))

(declaim (inline vec vec0 vec-x vec-y vec-z))

(defstruct (vec (:constructor vec0)
                (:constructor vec (x y z)))
  (x 0.0d0 :type double-float)
  (y 0.0d0 :type double-float)
  (z 0.0d0 :type double-float))

(declaim (ftype (function (vec vec) vec)
                +v -v *v %v))

(declaim (ftype (function (vec double-float) vec)
                *s))

(declaim (ftype (function (vec vec) double-float)
                dot))

(declaim (ftype (function (vec) vec)
                normv))

(declaim (inline +v -v *v *s %v normv dot))

(defun +v (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type vec a b))
  (vec (+ (vec-x a) (vec-x b))
       (+ (vec-y a) (vec-y b))
       (+ (vec-z a) (vec-z b))))

(define-compiler-macro +v (&whole form a b)
  (let ((dl (loop for arg in (list a b)
                  for l in (list '.a '.b)
                  when (and (consp arg)
                            (member (car arg)
                                    '(+v -v *v *s %v normv)))
                    collect l)))
    (if dl
        `(let ((.a ,a)
               (.b ,b))
           (declare (type vec .a .b)
                    (dynamic-extent ,@dl))
           (vec (+ (vec-x .a) (vec-x .b))
                (+ (vec-y .a) (vec-y .b))
                (+ (vec-z .a) (vec-z .b))))
        form)))

(defun -v (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
         (type vec a b))
  (vec (- (vec-x a) (vec-x b))
       (- (vec-y a) (vec-y b))
       (- (vec-z a) (vec-z b))))

(define-compiler-macro -v (&whole form a b)
  (let ((dl (loop for arg in (list a b)
                  for l in (list '.a '.b)
                  when (and (consp arg)
                            (member (car arg)
                                    '(+v -v *v *s %v normv vec)))
                    collect l)))
    (if dl
        `(let ((.a ,a)
               (.b ,b))
           (declare (type vec .a .b)
                    (dynamic-extent ,@dl))
           (vec (- (vec-x .a) (vec-x .b))
                (- (vec-y .a) (vec-y .b))
                (- (vec-z .a) (vec-z .b))))
        form)))

(defun *v (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type vec a b))
  (vec (* (vec-x a) (vec-x b))
       (* (vec-y a) (vec-y b))
       (* (vec-z a) (vec-z b))))

(define-compiler-macro *v (&whole form a b)
  (let ((dl (loop for arg in (list a b)
                  for l in (list '.a '.b)
                  when (and (consp arg)
                            (member (car arg)
                                    '(+v -v *v *s %v normv vec)))
                    collect l)))
    (if dl
        `(let ((.a ,a)
               (.b ,b))
           (declare (type vec .a .b)
                    (dynamic-extent ,@dl))
           (vec (* (vec-x .a) (vec-x .b))
                (* (vec-y .a) (vec-y .b))
                (* (vec-z .a) (vec-z .b))))
        form)))


(defun *s (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type vec a)
           (type double-float b))
  (vec (* (vec-x a) b)
       (* (vec-y a) b)
       (* (vec-z a) b)))

(define-compiler-macro *s (&whole form a b)
  (if (and (consp a)
           (member (car a) '(+v -v *v *s %v normv)))
      `(let ((.a ,a)
             (.b ,b))
         (declare (type vec .a)
                  (type double-float .b)
                  (dynamic-extent .a))
         (vec (* (vec-x .a) .b)
              (* (vec-y .a) .b)
              (* (vec-z .a) .b)))
      form))

(defun normv (a)
  (declare (optimize (speed 3) (space 0) (debug 0))
         (type vec))
  (let ((x (vec-x a))
        (y (vec-y a))
        (z (vec-z a)))
    (declare (type double-float x y z))
    (let ((s (/ (sqrt (+ (* x x)
                         (* y y)
                         (* z z))))))
      (*s a s))))

(define-compiler-macro normv (&whole form a)
  (if (and (consp a)
           (member (car a) '(+v -v *v *s %v vec)))
      `(let ((.a ,a))
         (declare (type vec .a)
                  (dynamic-extent .a))
         (let ((x (vec-x .a))
               (y (vec-y .a))
               (z (vec-z .a)))
           (declare (type double-float x y z))
           (let ((s (/ (sqrt (+ (* x x)
                                (* y y)
                                (* z z))))))
             (*s .a s))))
      form))

(defun dot (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type vec a b))
  (+ (* (vec-x a)
        (vec-x b))
     (* (vec-y a)
        (vec-y b))
     (* (vec-z a)
        (vec-z b))))

(define-compiler-macro dot (&whole form a b)
  (let ((dl (loop for arg in (list a b)
                  for l in (list '.a '.b)
                  when (and (consp arg)
                            (member (car arg)
                                    '(+v -v *v *s %v normv vec)))
                    collect l)))
    (if dl
        `(let ((.a ,a)
               (.b ,b))
           (declare (type vec .a .b)
                    (dynamic-extent ,@dl))
           (+ (* (vec-x .a)
                 (vec-x .b))
              (* (vec-y .a)
                 (vec-y .b))
              (* (vec-z .a)
                 (vec-z .b))))
        form)))

(defun %v (a b)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type vec a b))
  (vec (- (* (vec-y a) (vec-z b))
          (* (vec-z a) (vec-y b)))
       (- (* (vec-z a) (vec-x b))
          (* (vec-x a) (vec-z b)))
       (- (* (vec-x a) (vec-y b))
          (* (vec-y a) (vec-x b)))))

(define-compiler-macro %v (&whole form a b)
  (let ((dl (loop for arg in (list a b)
                  for l in (list '.a '.b)
                  when (and (consp arg)
                            (member (car arg)
                                    '(+v -v *v *s %v normv vec)))
                    collect l)))
    (if dl
        `(let ((.a ,a)
               (.b ,b))
           (declare (type vec .a .b)
                    (dynamic-extent ,@dl))
           (vec (- (* (vec-y .a) (vec-z .b))
                   (* (vec-z .a) (vec-y .b)))
                (- (* (vec-z .a) (vec-x .b))
                   (* (vec-x .a) (vec-z .b)))
                (- (* (vec-x .a) (vec-y .b))
                   (* (vec-y .a) (vec-x .b)))))
        form)))



(declaim (inline ray ray-o ray-d))

(defstruct (ray (:constructor ray (o d)))
  (o (vec0) :type vec)
  (d (vec0) :type vec))

(declaim (inline sphere-rad sphere-pos sphere-em sphere-col sphere-refl))

(defstruct (sphere (:constructor sphere (rad pos em col refl)))
  (rad 0.0d0 :type double-float)
  (pos (vec-init) :type vec)
  (em (vec-init) :type vec)
  (col (vec-init) :type vec)
  (refl :diff :type keyword))


(declaim (ftype (function (sphere ray) (double-float 0.0d0))
                intersect))

(declaim (inline intersect intersectp))

(defun intersect (s r)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type sphere s)
           (type ray r))
  (let* ((op (-v (sphere-pos s)
                 (ray-o r)))
         (eps 1d-4)
         (b (dot op (ray-d r)))
         (det (+ (- (* b b)
                    (dot op op))
                 (* (sphere-rad s)
                    (sphere-rad s)))))
    (declare (dynamic-extent op))
    (if (< det 0.0d0)
        0.0d0
        (let* ((det (sqrt det))
               (ta (- b det)))
          (if (> ta eps)
              ta
              (let ((ta (+ b det)))
                (if (> ta eps)
                    ta
                    0.0d0)))))))

(defparameter *scene*
  (list (sphere 1d5                     ; left
                (vec 100001d0 40.8d0 81.6d0) 
                (vec0)
                (vec 0.75d0 0.25d0 0.25d0)
                :diff)
        (sphere 1d5                     ; right
                (vec (+ -1d5 99d0) 40.8d0 81.6d0) 
                (vec0)
                (vec 0.25d0 0.25d0 0.75d0)
                :diff)
        (sphere 1d5                     ; back
                (vec 50d0 40.8d0 1d5) 
                (vec0)
                (vec 0.25d0 0.75d0 0.25d0)
                :diff)
        (sphere 1d5                     ; front
                (vec 50d0 40.8d0 (+ -1d5 170d0)) 
                (vec0)
                (vec0)
                :diff)
        (sphere 1d5                     ; floor
                (vec 50d0 1d5 81.6d0) 
                (vec0)
                (vec 0.75d0 0.75d0 0.75d0)
                :diff)
        (sphere 1d5                     ; top
                (vec 50d0 (+ -1d5 81.6d0) 81.6d0) 
                (vec0)
                (vec 0.75d0 0.75d0 0.75d0)
                :diff)
        (sphere 16.5d0                  ; mirror
                (vec 27d0 16.5d0 47d0) 
                (vec0)
                (*s (vec 1d0 1d0 1d0) 0.999d0)
                :spec)
        (sphere 16.5d0                  ; glas
                (vec 73d0 16.5d0 78d0) 
                (vec0)
                (*s (vec 1d0 1d0 1d0) 0.999d0)
                :refr)
        (sphere 1.5d0                   ; light
                (vec 50d0 (- 81.6d0 16.5d0) 81.6d0) 
                (*s (vec 4d0 4d0 4d0) 100d0)
                (vec0)
                :diff)))

(defparameter *lights* (loop for s in *scene*
                             unless (let ((em (sphere-em s))) ; skip non-lights
                                      (and (<= (vec-x em) 0.0d0)
                                           (<= (vec-y em) 0.0d0)
                                           (<= (vec-z em) 0.0d0)))
                               collect s))

(defparameter *num-spheres* (length *scene*))

(defparameter *spheres* (make-array *num-spheres*
                                    :element-type 'sphere
                                    :initial-contents *scene*))


(declaim (inline clamp to-int))

(declaim (ftype (function (double-float) (double-float 0.0d0 1.0d0))
                clamp))

(declaim (ftype (function (double-float) (unsigned-byte 8))
                to-int))

(defun clamp (x)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type double-float x))
  (cond
    ((< x 0.0d0)
     0.0d0)
    ((> x 1.0d0)
     1.0d0)
    (t
     x)))

(defun to-int (x)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type double-float x))
  (floor (+ (* (expt (clamp x) (/ 2.2d0))
               255.0d0)
            0.5d0)))


(declaim (ftype (function (ray) (values (or null sphere) double-float))
                intersectp))

(defun intersectp (r)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type ray r))
  (loop for s in *scene*
        for d double-float = (intersect s r)
        with ta double-float = 1d20
        with id = NIL
        when (< 0.0d0 d ta) do
          (setf ta d
                id s)
        finally (return (if (< ta 1d20)
                            (values id ta)
                            (values nil 0.0d0)))))

(declaim (inline mollify))

(defun mollify (l rd n nl dist type molif_r)
  (declare (optimize (speed 3) (space 0) (debug 0))
           (type double-float dist molif_r)
           (type keyword type)
           (type vec l rd n nl))
  (let* ((cos_max (/ (sqrt (+ 1.0d0 (power (/ molif_r dist) 2)))))
         (solid_angle (* 2.0d0 pi (- 1.0d0 cos_max)))
         (into (> (dot n nl) 0.0d0))
         (out (-v rd (*s n (* 2.0d0
                              (dot n rd))))))
    (declare (dynamic-extent out))
    (when (eq type :refr)
      (let* ((nc 1.0d0)
             (nt 1.5d0)
             (nnt (if into (/ nc nt) (/ nt nc)))
             (ddn (dot rd nl))
             (cos2t (- 1.0d0 (* nnt nnt (- 1.0d0 (* ddn ddn))))))
        (when (> cos2t 0.0d0)
          (let ((outr (normv (-v (*s rd nnt)
                                 (*s n (* (if into 1.0d0 -1.0d0)
                                          (+ (* ddn nnt) (sqrt cos2t))))))))
            (declare (dynamic-extent outr))
            (if (>= (dot l outr)
                    cos_max)
                (/ solid_angle)
                0.0d0)))))
    (if (>= (dot l out)
            cos_max)
        (/ solid_angle)
        0.0d0)))

(defun radiance (r depth En molif_r)
  (declare (type (unsigned-byte 8) depth)
           (type (integer 0 1) En)
           (type double-float molif_r))
  (multiple-value-bind (obj ta) (intersectp r)
    (declare (type (or null sphere) obj)
             (type double-float ta))
    (cond
      ((null obj)
       (vec0))
      ((> (incf depth) 5)
       (*s (sphere-em obj)
           (coerce En 'double-float)))
      (t
       (let* ((x (+v (ray-o r)
                     (*s (ray-d r) ta)))
              (n (normv (-v x (sphere-pos obj))))
              (nl (if (< (dot n (ray-d r)) 0.0d0)
                      n
                      (*s n -1.0d0)))
              (f (sphere-col obj))
              (e (vec0))
              (p (max (vec-x f) (vec-y f) (vec-z f))))
         (declare (dynamic-extent x e n))
         (if (and (= p 0.0d0)
                  (>= (random 1.0d0) p))
             (*s (sphere-em obj)
                 (coerce En 'double-float))
             (let ((f (*s f (/ p))))
               (declare (dynamic-extent f))
               (loop for s in *lights* do
                 (let* ((sw (-v (sphere-pos s) x))
                        (su (if (> (abs (vec-x sw)) 0.1d0)
                                (normv (%v (vec 0.0d0 1.0d0 0.0d0) sw))
                                (normv (%v (vec 1.0d0 0.0d0 0.0d0) sw))))
                        (sv (%v sw su))
                        (cos-a-max (sqrt (- 1.0d0
                                            (/ (* (sphere-rad s)
                                                  (sphere-rad s))
                                               (dot (-v x (sphere-pos s))
                                                    (-v x (sphere-pos s)))))))
                        (eps1 (random 1.0d0))
                        (eps2 (random 1.0d0))
                        (cos_a (+ (- 1.0d0 eps1)
                                  (* eps1 cos-a-max)))
                        (sin_a (sqrt (- 1.0d0 (* cos_a cos_a))))
                        (phi (* 2 pi eps2))
                        (l (normv (+v (+v (*s su (* (cos phi) sin_a))
                                          (*s sv (* (sin phi) sin_a)))
                                      (*s sw cos_a)))))
                   (declare (type double-float cos-a-max cos_a sin_a)
                            (dynamic-extent sw sv l))
                   (let ((id (intersectp (ray x l)))
                         (stype (sphere-refl obj)))
                     (when (eq id s)
                       (let ((omega (* 2 pi (- 1.0d0 cos-a-max))))
                         (setf e (+v e
                                     (*v f (*s (sphere-em s) 
                                               (* omega
                                                  (the double-float
                                                       (if (eq :diff stype)
                                                           (* (dot l nl) (/ pi))
                                                           (mollify l (ray-d r) n nl ta 
                                                                    stype molif_r)))))))))))))
               (case (sphere-refl obj)
                 (:diff
                  (let* ((r1 (random (* 2.0d0 pi)))
                         (r2 (random 1.0d0))
                         (r2s (sqrt r2))
                         (w nl)
                         (u (if (> (abs (vec-x w)) 0.1d0)
                                (normv (%v (vec 0.0d0 1.0d0 0.0d0) w))
                                (normv (%v (vec 1.0d0 0.0d0 0.0d0) w))))
                         (v (%v w u))
                         (d (normv (+v (+v (*s u (* (cos r1) r2s))
                                           (*s v (* (sin r1) r2s)))
                                       (*s w (sqrt (- 1.0d0 r2)))))))
                    (declare (dynamic-extent v))
                    (+v (+v (*s (sphere-em obj)
                                (coerce En 'double-float))
                            e)
                        (*v f (radiance (ray x d) depth 0 molif_r)))))
                 (:spec
                  (let* ((spawnv (-v (ray-d r)
                                     (*s n (* 2.0d0
                                              (dot n (ray-d r))))))
                         (spawn (ray x spawnv)))
                    (declare (dynamic-extent spawn spawnv))
                    (+v (sphere-em obj)
                        (*v f (radiance spawn depth 1 molif_r)))))
                 (:refr
                  (let* ((reflray (ray x (-v (ray-d r)
                                             (*s n (* 2.0d0
                                                      (dot n (ray-d r)))))))
                         (into (> (dot n nl) 0.0d0))
                         (nc 1.0d0)
                         (nt 1.5d0)
                         (nnt (if into (/ nc nt) (/ nt nc)))
                         (ddn (dot (ray-d r) nl))
                         (cos2t (- 1.0d0 (* nnt nnt (- 1.0d0 (* ddn ddn))))))
                    (declare (dynamic-extent reflray))
                    (if (< cos2t 0.0d0)
                        (+v (sphere-em obj)
                            (*v f (radiance reflray depth 1 molif_r)))
                        (let* ((tdir (normv (-v (*s (ray-d r) nnt)
                                                (*s n (* (if into 1.0d0 -1.0d0)
                                                         (+ (* ddn nnt) (sqrt cos2t)))))))
                               (a (- nt nc))
                               (b (+ nt nc))
                               (R0 (/ (* a a) (* b b)))
                               (c (- 1.0d0 (if into (- ddn) (dot tdir n))))
                               (Re (+ R0 (* (- 1.0d0 R0) c c c c c)))
                               (Tr (- 1.d0 Re))
                               (Pb (+ 0.25d0 (* 0.5d0 Re)))
                               (RP (/ Re Pb))
                               (TP (/ Tr (- 1.0d0 Pb)))
                               (tdirray (ray x tdir)))
                          (declare (dynamic-extent tdir tdirray))
                          (+v (sphere-em obj)
                              (*v f (if (> depth 2) ; Russian roulette
                                        (if (< (random 1.0d0) Pb)
                                            (*s (radiance reflray depth 1 molif_r) RP)
                                            (*s (radiance tdirray depth 1 molif_r) TP))
                                        (+v (*s (radiance reflray depth 1 molif_r) Re)
                                            (*s (radiance tdirray depth 1 molif_r) Tr)))))))))))))))))

(defun write-ppm (buffer &optional (filename "image.ppm"))
  (declare (type (simple-vector #.(* +xsize+ +ysize+)) buffer))
  (with-open-file (s filename :direction :output :if-exists :supersede)
    (format s "P3~%~s ~s~%~s~%" +xsize+ +ysize+ 255)
    (loop for v across buffer
          do (format s "~s ~s ~s "
                     (to-int (vec-x v))
                     (to-int (vec-y v))
                     (to-int (vec-z v))))))

(defvar *lp-initialized-p* (progn
                             (unless lparallel:*kernel*
                               (setf lparallel:*kernel* 
                                     (lparallel:make-kernel 2)) )
                             t))


(defun render (&optional (samples 1))
  (declare (type (unsigned-byte 32) samples))
  (let ((cam (ray (vec 50.0d0 52.0d0 295.6d0)
                  (normv (vec 0.0d0 -0.042612d0 -1.0d0))))
        (buffer (make-array (* +xsize+ +ysize+) :initial-element (vec0))))
    (declare (dynamic-extent cam))
    (let* ((cx (vec0 :x (/ (* (float +xsize+) 0.5135d0) (float +ysize+))))
           (cy (*s (normv (%v cx (ray-d cam))) 0.5135d0))
           (dsamples (/ 1.0d0 samples))
           (spp (* 4 samples)))
      (declare (dynamic-extent cx cy))
      (dotimes (y +ysize+ (write-ppm buffer))
        (format t "Rendering (~s spp) ~,2f~%"
                spp (float (/ (* 100 y) (1- +ysize+))))
        (lparallel:pdotimes (x +xsize+)
        ;(dotimes (x +xsize+)
          (loop for sy fixnum below 2
                with i fixnum = (+ (* (- +ysize+ y 1) +xsize+) x) do
                  (loop for sx fixnum below 2 do
                        (let ((r (vec0)))
                          (declare (dynamic-extent r))
                          (loop for s fixnum below samples
                                for molif_r double-float = (* 1.0d0 (expt (+ 1.0d0 s)
                                                                          (/ 1.0d0 6.0d0)))
                                for r1 double-float = (random 4.0d0)
                                for dx = (if (< r1 2.0d0)
                                             (- (sqrt r1) 2.0d0)
                                             (- 2.d0 (sqrt (- 4.0d0 r1))))
                                for r2 double-float = (random 4.0d0)
                                for dy = (if (< r2 2.0d0)
                                             (- (sqrt r2) 2.0d0)
                                             (- 2.d0 (sqrt (- 4.0d0 r2))))
                                for d = (+v (+v (*s cx
                                                    (- (/ (+ (/ (+ (float sx) 0.5d0 dx) 2.0d0)
                                                             (float x))
                                                          (float +xsize+))
                                                       0.5d0))
                                                (*s cy
                                                    (- (/ (+ (/ (+ (float sy) 0.5d0 dy) 2.0d0)
                                                             (float y))
                                                          (float +ysize+))
                                                       0.5d0)))
                                            (ray-d cam))
                                do (setf r
                                         (+v r (*s (radiance (ray (+v (ray-o cam)
                                                                      (*s d 140.0d0))
                                                                  (normv d))
                                                             0 1 molif_r)
                                                   dsamples)))
                                finally (setf (aref buffer i)
                                              (+v (aref buffer i)
                                                  (*s (vec (clamp (vec-x r))
                                                           (clamp (vec-y r))
                                                           (clamp (vec-z r)))
                                                      0.25d0))))))))))))
