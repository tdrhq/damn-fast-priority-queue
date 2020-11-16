;;;; damn-fast-priority-queue.lisp

(defpackage #:damn-fast-priority-queue
  (:use #:cl)
  (:local-nicknames (#:a #:alexandria))
  (:export #:queue #:make-queue #:enqueue #:dequeue #:peek #:size #:trim))

(in-package #:damn-fast-priority-queue)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Read-time variables

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *optimize-qualities*
    #+real-damn-fast-priority-queue
    ;; Good luck.
    `(optimize (speed 3) (debug 0) (safety 0) (space 0) (compilation-speed 0))
    #-real-damn-fast-priority-queue
    `(optimize (speed 3))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Type definitions

(deftype data-type () 't)

(deftype data-vector-type () '(simple-array data-type (*)))

(deftype prio-type () '(unsigned-byte 32))

(deftype prio-vector-type () '(simple-array prio-type (*)))

(deftype extension-factor-type () '(integer 2 256))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Structure definition

(declaim (inline %make %data-vector %prio-vector %size %extension-factor))

(defstruct (queue (:conc-name #:%) (:constructor %make)
                  (:predicate nil) (:copier nil))
  (data-vector (make-array 256 :element-type 'data-type) :type data-vector-type)
  (prio-vector (make-array 256 :element-type 'prio-type) :type prio-vector-type)
  (size 0 :type a:array-length)
  (extension-factor 2 :type extension-factor-type))

(declaim (inline make-queue))

(declaim (ftype (function (&optional a:array-index extension-factor-type)
                          (values queue &optional))
                make-queue))
(defun make-queue (&optional (initial-size 256) (extension-factor 2))
  (declare (type extension-factor-type extension-factor))
  (declare #.*optimize-qualities*)
  (%make :extension-factor extension-factor
         :data-vector (make-array initial-size :element-type 'data-type)
         :prio-vector (make-array initial-size :element-type 'prio-type)))

(defmethod print-object ((object queue) stream)
  (print-unreadable-object (object stream :type t :identity t)
    (format stream "(~D)" (%size object))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Enqueueing

(declaim (inline heapify-upwards enqueue))

(declaim (ftype (function (data-vector-type prio-vector-type a:array-length)
                          (values null &optional))
                heapify-upwards))
(defun heapify-upwards (data-vector prio-vector index)
  (declare (type data-vector-type data-vector))
  (declare (type prio-vector-type prio-vector))
  (declare (type a:array-length index))
  (declare #.*optimize-qualities*)
  (do ((child-index index parent-index)
       (parent-index (ash (1- index) -1) (ash (1- parent-index) -1)))
      ((= child-index 0))
    (let ((child-priority (aref prio-vector child-index))
          (parent-priority (aref prio-vector parent-index)))
      (cond ((< child-priority parent-priority)
             (rotatef (aref prio-vector parent-index)
                      (aref prio-vector child-index))
             (rotatef (aref data-vector parent-index)
                      (aref data-vector child-index)))
            (t (return))))))

(defmacro vector-push-replace (new-element position vector extension-factor)
  (a:with-gensyms (length new-length)
    (a:once-only (position)
      `(let ((,length (array-total-size ,vector)))
         (when (>= ,position ,length)
           (let ((,new-length (mod (* ,length ,extension-factor)
                                   (ash 1 64))))
             (declare (type a:array-length ,new-length))
             (when (<= ,new-length ,length)
               (error "Integer overflow while resizing array"))
             (setf ,vector (adjust-array ,vector ,new-length))))
         (setf (aref ,vector ,position) ,new-element)))))

(declaim (ftype (function (queue t fixnum) (values null &optional)) enqueue))
(defun enqueue (queue object priority)
  (declare (type queue queue))
  (declare (type fixnum priority))
  (declare #.*optimize-qualities*)
  (symbol-macrolet ((data-vector (%data-vector queue))
                    (prio-vector (%prio-vector queue)))
    (let ((size (%size queue))
          (extension-factor (%extension-factor queue)))
      (vector-push-replace object size data-vector extension-factor)
      (vector-push-replace priority size prio-vector extension-factor)
      (heapify-upwards data-vector prio-vector (%size queue))
      (incf (%size queue))
      nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Dequeueing

(declaim (inline heapify-downwards dequeue))

(declaim (ftype (function (data-vector-type prio-vector-type a:array-index)
                          (values null &optional))
                heapify-downwards))
(defun heapify-downwards (data-vector prio-vector size)
  ;; spychaj przestawiony wierzchołek w dół, zamieniając pozycjami z większymi
  ;; z dzieci, aż do przywrócenia warunku kopca (czyli aż dzieci będą mniejsze
  ;; od k lub element dotrze na spód kopca)
  (declare (type data-vector-type data-vector))
  (declare (type prio-vector-type prio-vector))
  (declare #.*optimize-qualities*)
  (let ((parent-index 0))
    (loop
      (let* ((left-index (+ (* parent-index 2) 1))
             (left-index-validp (< left-index size))
             (right-index (+ (* parent-index 2) 2))
             (right-index-validp (< right-index size)))
        (flet ((swap-left ()
                 (rotatef (aref prio-vector parent-index)
                          (aref prio-vector left-index))
                 (rotatef (aref data-vector parent-index)
                          (aref data-vector left-index))
                 (setf parent-index left-index))
               (swap-right ()
                 (rotatef (aref prio-vector parent-index)
                          (aref prio-vector right-index))
                 (rotatef (aref data-vector parent-index)
                          (aref data-vector right-index))
                 (setf parent-index right-index)))
          (declare (inline swap-left swap-right))
          (when (and (not left-index-validp)
                     (not right-index-validp))
            (return))
          (when (and left-index-validp
                     (< (aref prio-vector parent-index)
                        (aref prio-vector left-index))
                     (or (not right-index-validp)
                         (< (aref prio-vector parent-index)
                            (aref prio-vector right-index))))
            (return))
          (if (and right-index-validp
                   (<= (aref prio-vector right-index)
                       (aref prio-vector left-index)))
              (swap-right)
              (swap-left)))))))

(declaim (ftype (function (queue) (values t boolean &optional)) dequeue))
(defun dequeue (queue)
  (declare (type queue queue))
  (declare #.*optimize-qualities*)
  (if (= 0 (%size queue))
      (values nil nil)
      (let ((data-vector (%data-vector queue))
            (prio-vector (%prio-vector queue)))
        (multiple-value-prog1 (values (aref data-vector 0) t)
          (let ((old-data (aref data-vector (1- (%size queue))))
                (old-prio (aref prio-vector (1- (%size queue)))))
            (setf (aref data-vector 0) old-data
                  (aref prio-vector 0) old-prio))
          (decf (%size queue))
          (heapify-downwards data-vector prio-vector (%size queue))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Introspection and maintenance

(declaim (inline peek size trim))

(declaim (ftype (function (queue) (values t boolean &optional)) peek))
(defun peek (queue)
  (declare (type queue queue))
  (declare #.*optimize-qualities*)
  (if (= 0 (%size queue))
      (values nil nil)
      (values (aref (%data-vector queue) 0) t)))

(declaim (ftype (function (queue) (values a:array-length &optional)) size))
(defun size (queue)
  (declare (type queue queue))
  (declare #.*optimize-qualities*)
  (%size queue))

(declaim (ftype (function (queue) (values null &optional)) trim))
(defun trim (queue)
  (declare (type queue queue))
  (declare #.*optimize-qualities*)
  (let ((size (%size queue)))
    (setf (%data-vector queue) (adjust-array (%data-vector queue) size)
          (%prio-vector queue) (adjust-array (%prio-vector queue) size))
    nil))
