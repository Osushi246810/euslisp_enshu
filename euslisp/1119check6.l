

(load "package://roseus/test/joy.l")
(load "package://dxl_armed_turtlebot/euslisp/dxl-armed-turtlebot-interface.l")
(dxl-armed-turtlebot-init)
(init-ps3joy) ;; *joy* という大域変数のセッ
(ros::rate 10)
(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
(do-until-key
	(ros::spin-once)
	(ros::sleep)
	(if (= (send *joy* :circle-button) 1)
		(progn
			;;(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
			(send *dxl-armed-turtlebot* :angle-vector
				(v+ (send *dxl-armed-turtlebot* :angle-vector) #f(0 0 0 5 0 0 0)))
			(send *irtviewer* :draw-objects) ;; 描画
			(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 100) ;
			(send *ri* :wait-interpolation) ;; 補間をまつ
		)
	)
	(if (= (send *joy* :cross-button) 1)
		(progn
			;;(send *dxl-armed-turtlebot* :reset-pose) ;; 関節角度を :init-pose にセット
			(send *dxl-armed-turtlebot* :angle-vector
				(v+ (send *dxl-armed-turtlebot* :angle-vector) #f(0 0 0 -5 0 0 0)))
			(send *irtviewer* :draw-objects) ;; 描画
			(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 100) ;
			(send *ri* :wait-interpolation) ;; 補間をまつ
		)
	)
	(if (= (send *joy* :triangle-button) 1)
		(progn
			(send *dxl-armed-turtlebot* :reset-pose) ;; 関節角度を :init-pose にセット
			(send *irtviewer* :draw-objects) ;; 描画
			(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000) ;
			(send *ri* :wait-interpolation) ;; 補間をまつ
		)
	)
	(if (= (send *joy* :square-button) 1)
		(progn
			(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
			(send *irtviewer* :draw-objects) ;; 描画
			(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 1000) ;
			(send *ri* :wait-interpolation) ;; 補間をまつ
		)
	)
	(send *joy* :ljoy-lr)
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