;; robotの初期化
(load "package://dxl_armed_turtlebot/euslisp/dxl-armed-turtlebot-interface.l")
(load "package://roseus/test/joy.l")

(dxl-armed-turtlebot-init)
(init-ps3joy) ;; *joy* という大域変数のセッ
(ros::rate 100)
(setq vec #f(0 0 0))
(setq lr 0)
(setq fb 0)
;; jsk_pcl_rosのmsgを使うため、loadする
;;(ros::load-ros-manifest "jsk_pcl_ros")
(ros::load-ros-manifest "jsk_recognition_msgs")

;; クラスタリング結果であるBoundingBoxのtopic名
;;(defvar *topic-name* "/camera/depth_registered/cluster_decomposer/boxes")
(defvar *topic-name* "/camera/depth_registered/boxes")
(defvar *bounding-box-list* nil)

;; ros::initする
(ros::roseus "boundingboxarray_subscriber")

(setq *target* (make-cube 10 10 10))

;; コールバック関数
(defun bounding-box-array-cb (msg)
  (setq *bounding-box-list* (send msg :boxes)) ;; boxesは、BoundingBoxのArray(Euslispではlist)
  ;; BoundingBoxがあれば表示する
  (when *bounding-box-list*
    (send *irtviewer* :draw-objects :flush nil)
    (mapcar #'(lambda (b)
                ;; BoundingBoxは、dimsntion(直方体の幅・奥行き・高さ)をもつ
                (let* ((dims (ros::tf-point->pos (send b :dimensions)))
                       (bx (make-cube (elt dims 0) (elt dims 1) (elt dims 2)))
                       ;; (1) BoundingBoxのカメラ相対の座標系は、geometry_msgs/Poseという型で得られるので、Euslispのcoordsに変換する
                       (cam->obj-coords (ros::tf-pose->coords (send b :pose)))
                       ;; (2) *dxl-armed-turtlebot*モデルがカメラの座標系をもってるので、取得する
                       (cam-coords (send (send *dxl-armed-turtlebot* :camera_rgb_optical_frame_lk) :copy-worldcoords)))
                  ;; (3) Euslisp内部でのworld座標系の値にして、そこにmake-cubeの箱を設置する
                  (send bx :newcoords (send cam-coords :transform cam->obj-coords))
                  (send bx :worldcoords)
                  (send bx :draw-on :flush nil :color #f(1 0 0)) ;; 描画
                  ;;inverse-kinematics
                  (if (= (send *joy* :square-button) 1)
                    (progn
                      (print 3)
                      (send *target* :locate (send bx :worldpos) :world)
                      (print (send *target* :worldpos))
                    )
                  )
                )
              )
              *bounding-box-list*
    )
  )
)

(ros::subscribe *topic-name* jsk_recognition_msgs::BoundingBoxArray #'bounding-box-array-cb 1)

(do-until-key
  (x::window-main-one) ;; IRT viewerの視点を変えられる。見にくければ変えよう

  (setq lr (* 0.1 (send *joy* :ljoy-lr)))
  (setq fb (* 0.1 (send *joy* :ljoy-fb)))

  (if (< fb 0.01)
    (progn
      (if (> fb -0.01)
        (setq fb 0)
        nil)
    )
    nil)

  (send *ri* :go-velocity fb 0 0)
  (send *ri* :go-pos fb 0 lr)

  (send *dxl-armed-turtlebot* :translate (float-vector (* 700 fb) 0 0))
  (send *dxl-armed-turtlebot* :rotate lr :z)

  (if (= (send *joy* :circle-button) 1)
    (progn
      (print 1)
      ;(send *target* :translate #f(0 70 0))
      ;位置合わせ
      (send *dxl-armed-turtlebot* :inverse-kinematics
        (send *target* :worldcoords)
        :rotation-axis nil
        :translation-axis t
        :warnp nil
        :revert-if-fail nil)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
      ;持ちやすい姿勢
      (send *dxl-armed-turtlebot* :inverse-kinematics
        (send *target* :worldcoords)
        :rotation-axis :-z
        :translation-axis t
        :warnp nil
        :revert-if-fail nil)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 500) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )

  (if (= (send *joy* :cross-button) 1)
    (progn
      (print 2)
      (send *dxl-armed-turtlebot* :reset-pose2)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )

  (if (= (send *joy* :triangle-button) 1)
    (progn
      (print 4)
      (setq pos (send *target* :pos))
      (setq pos (v* #f(0.001 0.001 0.001) pos))
      (send *ri* :go-pos (elt pos 0) (elt pos 2) 0)
      (send *dxl-armed-turtlebot* :locate pos)
    )
  )


  (if (= (send *joy* :r1-button) 1)
    (progn
      (print 5)
      ;(send *dxl-armed-turtlebot* :gripper :arm :angle-vector #f(50))
      ;(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000 :gripper-controller)
      ;(send *ri* :wait-interpolation :gripper-controller)
      (send *ri* :start-grasp)
      ;(send *ri* :stop-grasp)
    )
  )
  (if (= (send *joy* :l1-button) 1)
    (progn
      (print 6)
      ;(send *dxl-armed-turtlebot* :gripper :arm :angle-vector #f(50))
      ;(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000 :gripper-controller)
      ;(send *ri* :wait-interpolation :gripper-controller)
      ;(send *ri* :start-grasp)
      (send *ri* :stop-grasp)
    )
  )

  (if (= (send *joy* :up-button) 1)
    (progn
      (setq vec #f(0 0 5))
      (send *dxl-armed-turtlebot* :arm :move-end-pos vec)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 10) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )
  (if (= (send *joy* :down-button) 1)
    (progn
      (setq vec #f(0 0 -5))
      (send *dxl-armed-turtlebot* :arm :move-end-pos vec)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 10) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )
  (if (= (send *joy* :left-button) 1)
    (progn
      (setq vec #f(0 5 0))
      (send *dxl-armed-turtlebot* :arm :move-end-pos vec)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 10) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )
  (if (= (send *joy* :right-button) 1)
    (progn
      (setq vec #f(0 -5 0))
      (send *dxl-armed-turtlebot* :arm :move-end-pos vec)
      (send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 10) ;
      (send *ri* :wait-interpolation) ;; 補間をまつ
    )
  )

  (send *target* :draw-on :flush nil :color #f(0 0 1))
  (send *irtviewer* :viewer :viewsurface :flush)
  ;(send *irtviewer* :draw-objects)
  (ros::spin-once)
  (ros::sleep)
)

