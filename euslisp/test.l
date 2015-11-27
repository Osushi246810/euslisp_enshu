(load "package://dxl_armed_turtlebot/euslisp/dxl-armed-turtlebot-interface.l")
(dxl-armed-turtlebot-init)
;; アーム+台車ロボットの *ri* と *dxl-armed-turtlebot* を生成
(do-until-key
(send *dxl-armed-turtlebot* :init-pose) ;; 関節角度を :init-pose にセット
(send *irtviewer* :draw-objects) ;; 描画
(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 4000) ;;4000[ms] で実行
(send *ri* :wait-interpolation) ;; 補間をまつ
(send *dxl-armed-turtlebot* :reset-pose) ;; 関節角度を :reset-pose にセット
(send *irtviewer* :draw-objects) ;; 描画
(send *ri* :angle-vector (send *dxl-armed-turtlebot* :angle-vector) 4000) ;;4000[ms] で実行
(send *ri* :wait-interpolation) ;; 補間をまつ
)