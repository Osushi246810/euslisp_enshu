

(load "package://roseus/test/joy.l")
(load "package://dxl_armed_turtlebot/euslisp/dxl-armed-turtlebot-interface.l")
(dxl-armed-turtlebot-init)
(init-ps3joy) ;; *joy* という大域変数のセッ
(ros::rate 1)
(setq vec #f(0 0 0))
(setq lr 0)
(setq fb 0)

(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
(send *irtviewer* :draw-objects) ;; 描画
(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000) ;
(send *ri* :wait-interpolation) ;; 補間をまつ

(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
(do-until-key
	(ros::spin-once)
	(ros::sleep)
	(setq vec #f(0 0 0))

	(setq lr (send *joy* :ljoy-lr))
	(setq fb (send *joy* :ljoy-fb))
	(setq ud (send *joy* :rjoy-fb))
	(setq vec (v+ vec (float-vector (* 3 lr) (* 3 fb) (* 3 ud))))
	(print vec)
	(send *dxl-armed-turtlebot* :arm :move-end-pos vec)

	(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1) ;
	(send *ri* :wait-interpolation) ;; 補間をまつ

	(send *irtviewer* :draw-objects)
)


#|
(:ljoy-lr :ljoy-fb :rjoy-lr :rjoy-fb :arrow-f :arrow-b :arrow-r :arrow-l :accel\
eration-sensor-rl :acceleration-sensor-fb :acceleration-sensor-ud :gyro-sensor-\
yaw)

(:select-button :l3-button :r3-button :start-button :up-button :right-button :d\
own-button :left-button :l2-button :r2-button :l1-button :r1-button :triangle-b\
utton :circle-button :cross-button :square-button :pairing-button)

#f(0.0 0.0 -90.0 0.0 90.0 0.0 0.0)
|#