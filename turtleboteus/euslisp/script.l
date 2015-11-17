


(progn
	(loop
		(if (> (v. (send *ri* :state :button-vector) #f(1 1 1)) 0)
			(return 0)))
	(loop
		(send *ri* :go-velocity 0.1 0 0)
		(if (> (v. (send *ri* :state :bumper-vector) #f(1 1 1)) 0)
			(return 0)))
	(send *ri* :go-velocity 0 0 0))

