(in-package #:play-with-verts)

(defvar *last-time* (get-internal-real-time))

(defvar *scene-fbo* nil)
(defvar *scene-sampler* nil)

(defvar *los-scene* nil)

(defclass los-scene ()
  ((cube-map :initarg :cube-map)
   (fbos :initarg :fbos)
   (sampler :initarg :sampler)))

(defun make-los-scene ()
  (let ((scene (make-instance 'los-scene)))
    (with-slots (cube-map fbos sampler) scene
      (setf cube-map (make-texture
                      nil
                      :element-type :uint8
                      :dimensions '(512 512)
                      :cubes t)
            fbos (loop :for i :below 6 :collect
                      (make-fbo
                       (list 0 (texref cube-map :cube-face i))))
            sampler (sample cube-map))
      scene)))

(defmethod free ((obj los-scene))
  (with-slots (cube-map fbos sampler) obj
    (free cube-map)
    (map nil #'free fbos)
    (free sampler)
    nil))

(defvar *fallback-normal-map* nil)

(defun reset (&key force)
  ;;
  ;; on first startup
  (when (or force (not *scene-fbo*))
    (setf (clear-color) (v! 0.2 0.2 0.2 0))
    (setf *things* nil)
    (setf *fallback-normal-map*
          (sample
           (make-texture (list (list (v! 0.5 0.5 1)))
                         :dimensions '(1 1)
                         :mipmap nil)))
    ;;
    ;; Add some things to the scene
    (load-assimp-things "sponza_obj/sponza.obj" 0.2f0)
    (make-ball (v! 0 10 20) 3.0)
    (reset-lights))
  ;;
  ;; every time
  (reset-fbos)
  (reset-camera))

(defun reset-fbos ()
  (when *scene-fbo*
    (free *scene-fbo*))
  (setf *scene-fbo*
        (make-fbo (list 0 :element-type :rgba16f)
                  (list 1 :element-type :rgba16f)
                  :d))
  (setf *scene-sampler*
        (sample (attachment-tex *scene-fbo* 0))))

(defun reset-lights ()
  (when *lights*
    (free *lights*)
    (free *lights-arr*))

  (let* ((light-data (make-c-array nil :dimensions 1
                                   :element-type 'light-set))
         (set (aref-c light-data 0))
         (plights (light-set-plights set)))

    (setf (light-set-count set) 3)

    (setf (aref-c plights 0) (list (v! 0 5 -18)
                                   (v! 1 1 1)
                                   1300.0)
          (aref-c plights 1) (list (v! 0 120 24)
                                   (v! 1 1 1)
                                   3200.0)
          (aref-c plights 2) (list (v! 200 15 -10)
                                   (v! 1 1 1)
                                   3200.0))

    (setf *lights-arr* (make-gpu-array light-data)
          *lights* (make-ubo *lights-arr* 'light-set))))

(defun game-step ()
  (let* ((now (get-internal-real-time))
         (delta (* (- now *last-time*) 0.001))
         (delta (if (> delta 0.16) 0.00001 delta)))
    (setf *last-time* now)

    ;; update camera
    (update *current-camera* delta)

    ;; set the position of our viewport
    (setf (resolution (current-viewport))
          (surface-resolution (current-surface)))

    ;; draw stuff
    (with-fbo-bound (*scene-fbo*)
      (clear-fbo *scene-fbo*)
      (loop :for thing :in *things* :do
           (update thing delta)
           (draw *current-camera* thing)))

    (as-frame
      (fxaa3-pass *scene-sampler*)
      ;;(draw-tex *scene-sampler*)
      )

    (decay-events)))

;; (defun foo ()
;;   (with-fbo-bound (*scene-fbo*)
;;     (clear-fbo *scene-fbo*)
;;     (loop :for thing :in *things* :do
;;          (update thing delta)
;;          (draw *current-camera* thing))))


(def-simple-main-loop play (:on-start #'reset)
  (game-step))

;; (sdl2-game-controller-db:load-db)
;; (defvar *pad* (sdl2:game-controller-open 0))
;; (skitter.sdl2:enable-background-joystick-events)
