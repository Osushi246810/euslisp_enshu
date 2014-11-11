;;
;; robot-server��simulation���륯�饹�����
;;  daisya���ꤷ�Ƥ���Τǳ�ĥ����˳�����Τ�����
;;
(load "daisya.l")
(load "virtual_interpolator.l")
(defvar *sim*)
(defun sim-update () (send *sim* :update)) ;;timer-job����Ͽ����update�ؿ�

#|********************************************
 ���ۤ���robot-server-simulator��eus-server�Ȥ���
 �̥ץ������ǵ�ư����������Ф���socket��connect����
 ��������뤳�Ȥǡ����蹹�������������褹��
**********************************************|#
(defvar *host* "127.0.0.1")
;;world-objs�������򵭽Ҥ����ǥ�
(defun start-robotsim-server
  (world-objs &key (port 5000) (init-coords (make-cascoords)))
  (let ()
    (when (not (boundp' *daisya*)) 
      (setq *daisya* (instance daisyaclass :init)))
    (send *daisya* :newcoords init-coords)
    (cond 
     ((not *sim*)
      (setq *sim* (instance daisya-server-simulator :init
			       *daisya* world-objs))
      (send *sim* :start)
      (unix:usleep (* 500 1000))
      (warn "start eus server~%")
      ;;eus-server��Ω���夲��
      (eus-server port :host *host*)
      )
     (t
      (send *sim* :rebuild-world world-objs)
      ))
    ))

#|***********************************************
 eus-server���̥ץ������ǵ�ư����robot-server-simulator
 ���Ф���Ʊ��interface�ǻ�������뤿��Υ��饹
************************************************|#
(defvar *rs-sim* nil)
(defvar *vs-sim* nil)
(defun connect-robotsim-server
  (&key (port 5000) (host *host*))
  (setq *rs-sim* 
	(instance robotsim-server-connector :init 
					    :host host 
					    :port port)))
(defun connect-visionsim-server
  ()
  (setq *vs-sim* *rs-sim*))

(defvar *sim-lock* (sys::make-mutex-lock))
(defclass robotsim-server-connector
  :super propertied-object
  :slots
  (server-strm
   ))
(defmethod robotsim-server-connector
  (:init 
   (&key (port 5000) (host *host*))
   (setq server-strm (connect-server-until-success host port))
   self)
  ;;command������
  (:send
   (&rest command)
   (let ((com "(send *sim*") ret)
     (sys::mutex
      *sim-lock*
     (finish-output server-strm) ;;�ǽ�����ˤ��롩
     (cond 
      ((not command) 
       (return-from :send)
       )
      (t
       (dolist (c command)
	 (setq com (concatenate string com " " 
				(format nil "~a" c))))
       (setq com (concatenate string com ")~%"))
       ;;(print com)
       (format server-strm com)
       ;;
       ;;����äȵ٤फ
       (unix:usleep 10000)
       ;;(when (select-stream (list server-strm) 5)
       ;;(setq ret (read server-strm))
       (let ((tmp-strm (select-stream (list server-strm) 0.001)))
         (if tmp-strm (setq ret (read (car tmp-strm)))))
       ))
     ret)))
  ;;�����������Ƥ��ʤ�method���ƤФ줿��硢���줬�ƤФ��.
  ;;  ���ΤȤ�method̾���ߤǡ������ȤȤ��args���Ϥ����
  (:nomethod
   (&rest args)
   (if (assoc (car args) (send daisya-server-simulator :methods))
       (send* self :send args)
     (warn "Can't find method ~A ,~A~%" (car args) (cdr args)))
   )
  ;; for vision-simulator
  (:result () (send self :send ":camera-vector"))
  )

#|*********************************************
   ���ܥåȤ����������simulator���饹�����
    ����������ȡ����⤪���ʤ�
**********************************************|#
(defclass robot-server-simulator
  :super propertied-object
  :slots
  (robot         ;;robotmodel�����
   world-objects ;;�������������body�ʤɤ�object��list
   viewer        ;;viewer
   camview       ;;camera viewer
   tick-time     ;;�ɤΤ��餤��γ�٤�simulation���뤫   [msec]
   world-bodies
   ))
(defmethod robot-server-simulator
  (:init
   (rbt wld-objs &key ((:tick-time tt) 20))
   (setq robot rbt
	 world-objects wld-objs)
   (setq tick-time tt)
   (setq viewer (make-irtviewer))
   ;;
   (setq camview
         (view
          :x 320 :y 240
          :viewing (send rbt :camera :viewing)
          :viewsurface
          (instance gl::glviewsurface :create  :glcon ((send viewer :viewer :viewsurface) . gl::glcon)
                    :title "daisha-view" :width 320 :height 240)
          :title "daisya view"
          ))

   ;;������������bodies���Ǽ����
   (setq world-bodies nil)
   (dolist (obj world-objects)
     (cond 
      ((derivedp obj body)
       (push obj world-bodies))
      (t
       (setq world-bodies (append (send obj :bodies) world-bodies)))
      ))
   ;;objects��ɽ��
   (objects (cons robot world-objects))
   self)
  ;;
  ;;simulation��������ʤ��Ȥ��ν����򤫤�(���蹹���ʤ�)
  (:update
   ()
   (let ((near gl::*perspective-near*)
         (far gl::*perspective-far*)
         (cam (send robot :camera)))
     (setq gl::*perspective-near* (send cam :hither))
     (setq gl::*perspective-far* (send cam :yon))
     (send camview :viewsurface :makecurrent)
     ;;(send cam :draw-objects camview (send viewer :objects))
     (setq gl::*perspective-near* near)
     (setq gl::*perspective-far* far)
     ;;
     (send viewer :viewer :viewsurface :makecurrent)
     (send viewer :draw-objects)
     ))
  ;;simulation�򥹥����Ȥ���
  (:start
   ()
   ;;γ�٤�����
   (setq *top-selector-interval* (* tick-time 0.001))
   (pushnew 'sim-update *timer-job*)
   (warn "simulation start!~%")
   )
  ;;simulation�򥹥ȥåפ���
  (:stop
   ()
   ;;γ�٤�Ӥ��ᤷ�Ƥ����餷�� (particle.l�򻲹�)
   (setq *top-selector-interval* 2)
   (setq *timer-job* (remove 'sim-update *timer-job*))
   (warn "simulation stop!~%")
   )
  ;;accessor
  (:robot (&rest args) (forward-message-to-all robot args))
  )

#|*********************************************
   ��֤Τ����server-simulator
     ��֤Τ����arm,wheel,sensor���֤򹹿�������Ȥ����Ҥ����

   <����method>
    daisya-velocity-vector

   <̤����method>
    wheel�Υ��ߥ�졼�������񤷤�����������Ƥ��ʤ�
      �ɤΤ褦��wheel��ư�����ȡ���֤ΰ��֤��ɤ��ʤ뤫�Ϸ׻��ǵ���ΤϺ���ʤ���

**********************************************|#
;;wheel������⡼��(ͽ���ֹ�)  robot-client.l�ȶ���
(defvar *PWM_CONTROL* 0)
(defvar *VELOCITY_CONTROL* 1)
(defvar *ANGLE_CONTROL* 2)
;;servo���������(ͽ���ֹ�)   robot-client.l�ȶ���
(defvar *INTERPOLATE_FINISH* 0)
(defvar *INTERPOLATE_LINEAR* 1)
(defvar *INTERPOLATE_MINJERK* 2)
;;
(defclass daisya-server-simulator
  :super robot-server-simulator
  :slots
  (
   ;;robot(daisya)���������֤򵭽Ҥ����ѿ��������
   ;; for wheel
   daisya-velocity-vector   ;;(xvec[mm/sec], yvec[mm/sec], rotvec[deg/sec])
   wheel-controlmode-vector ;;���ؤ�����⡼��
   ;; for arm
   arm-linear-interpolator  ;;�Ӥ���ִ�(linear)
   arm-minjerk-interpolator ;;�Ӥ���ִ�(minjerk)
   arm-current-interpolator
   ;;arm-angle-vector         ;;�Ӥ���ɸ����vector
   arm-interpolation-method ;;�Ӥ���֥⡼��
   arm-poweron-vector       ;;�Ӥ�����⡼��
   ;;
   ;; for sensor(obstacle)
   collision-count
   initial-rbt-pos
   initial-rbt-rot
   ;;
   ;; for daisya ��������
   daisya-linear-interpolator  ;;��֤���ִ�(linear)
   daisya-minjerk-interpolator ;;��֤���ִ�(minjerk)
   daisya-current-interpolator
   daisya-prev-posvector
   daisya-controlmode
   ;;
   ;;noise  ;;robot���ɤΤ褦�ʳ�Ψ��ǥ��ư�����Ȥ�����ꤹ��Τ���..
   ))
(defmethod daisya-server-simulator
  (:init
   (rbt wld &key ((:tick-time tt) 20))
   (send-super :init rbt wld :tick-time tt)
   (send self :wheel-reset)
   ;;
   ;;���ܥåȤν�����֤򵭲����Ƥ���
   (setq initial-rbt-pos (copy-seq (send robot :worldpos)))
   (setq initial-rbt-rot (copy-object (send robot :worldrot)))
   ;;
   ;;arm�Τ�����䴰�����
   (setq arm-linear-interpolator
	 (instance linear-interpolator :init :sec/step (* tick-time 0.001)))
   (setq arm-minjerk-interpolaor
	 (instance minjerk-interpolator :init :sec/step (* tick-time 0.001)))
   ;;daisya�Τ������ִ����
   (setq daisya-linear-interpolator
	 (instance linear-interpolator :init :sec/step (* tick-time 0.001)))
   (setq daisya-current-interpolator daisya-linear-interpolator)
   (setq daisya-prev-posvector (float-vector 0 0 0))
   ;;��֤�����⡼�ɤ�1(®��), 2(����)
   (setq daisya-controlmode 1)
   ;;
   ;;����⡼�ɤϥǥե���ȤǤ�OFF
   (setq arm-poweron-vector #f(0 0 0 0 0))
   ;;default�Ǥ��Ӥ��䴰�⡼�ɤ�����
   (setq arm-interpolation-method *INTERPOLATE_LINEAR*)
   (setq arm-current-interpolator arm-linear-interpolator)
   ;;
   (setq collision-count 0)
   ;;   
   self)
  ;;
  ;;������֤��᤹
  (:reset
   ()
   ;;���٥��ߥ�졼������ߤ��
   (send self :stop)
   ;;robot�򸵤��᤹
   (send robot :move-to (make-cascoords :pos initial-rbt-pos 
					:rot initial-rbt-rot) :world)
   (setq collision-count 0)
   (send self :start)
   )
  ;;�Ķ����֤�������
  (:rebuild-world
   (objs)
   (send self :stop)
   ;;������־���򹹿�
   (setq initial-rbt-pos (copy-seq (send robot :worldpos)))
   (setq initial-rbt-rot (copy-object (send robot :worldrot)))
   ;;ʪ�Τ򹹿�
   ;;������������bodies���Ǽ����
   (setq world-objects objs)
   (setq world-bodies nil)
   (dolist (obj world-objects)
     (cond 
      ((derivedp obj body)
       (push obj world-bodies))
      (t
       (setq world-bodies (append (send obj :bodies) world-bodies)))
      ))
   ;;objects��ɽ��
   (objects (cons robot world-objects))
   ;;
   (setq collision-count 0)
   (send self :start)
   )
  ;;
  ;;timer-job�����ƤФ��
  (:update
   ()
   ;;��֤�ư����
   (send self :update-daisya-position)
   ;;�Ӥ�ư����
   (send self :update-arm-angle)
   ;;sensor�򥷥ߥ�졼�����(����Ƚ�ꡢ��Υ�׻�)����
   (send self :update-sensor-value)
   ;;���蹹��
   (send-super :update)
   )
  ;;
  ;;�����ؿ������
  ;;
  ;;��֤ΰ��֤�wheel-velocity-vector�˽��äƹ���
  (:update-daisya-position
   ()
   (let* ((diff-x (* (aref wheel-velocity-vector 0) tick-time 0.001))
	  (diff-y (* (aref wheel-velocity-vector 1) tick-time 0.001))
	  (diff-rot (* (aref wheel-velocity-vector 2) tick-time 0.001))
          tmp-angle-vector
	  )
     (cond
      ;;��ְ�������ξ��
      ((= daisya-controlmode 2)
       ;;���ߤ���ִ�λ��֤�ʤ�ơ�������٤��Ȥ��robot������
       (setq tmp-angle-vector
             (send daisya-current-interpolator :pass-time (send daisya-current-interpolator :sec/step)))
       ;;��֤���λ���Ƥ�����nil���ѤäƤ���
       (when tmp-angle-vector
         ;;wheel-velocity-vector�򹹿����Ƥ����ʤ��ȡ��֤Ĥ��ä��Ȥ��ˤȤޤ�ʤ�
         (dotimes (i 3)
           (setf (aref wheel-velocity-vector i)
                 (/ (- (aref tmp-angle-vector i) (aref daisya-prev-posvector i)) (* tick-time 0.001)))
           )
         (send robot :move (v- tmp-angle-vector daisya-prev-posvector))
         ;;����λ����Ф��Ƥ���
         (dotimes (i 3)
           (setf (aref daisya-prev-posvector i) (aref tmp-angle-vector i)))
         )
       )
      ;;���®������ξ��
      (t
       (send robot :move (float-vector diff-x diff-y diff-rot))
       ))
     ))
  ;;�Ӥλ����򹹿�
  (:update-arm-angle
   ()
   (let (tmp-angle-vector im)
     ;;���ߤ��䴰��λ��֤�ʤ�ơ�������٤��Ȥ��robot������
     (setq tmp-angle-vector
	   (send arm-current-interpolator :pass-time (send arm-current-interpolator :sec/step)))
     ;;(print tmp-angle-vector)
     ;;�䴰����λ���Ƥ�����nil���ѤäƤ���
     (when tmp-angle-vector
       ;;poweron-vector��0�Τ�Τˤ�mask�򤫤���ư�����ʤ�
       (dotimes (i (length tmp-angle-vector))
	 (when (= (aref arm-poweron-vector i) 0)
	   (setf (aref tmp-angle-vector i) 0)))
       (send robot :angle-vector tmp-angle-vector))
     ))
  (:update-sensor-value
   ()
   ;;����Ƚ����Υ¬���Ԥ�
   (when world-bodies (send robot :simulate world-bodies))
   ;;���ͤ�������Ĵ�٤�
   (cond 
    ;;���ͤ��Ƥ��ʤ��ʤ��
    ((= (norm (send robot :bumper-vector)) 0)
     (setq collision-count 0))
    ;;���ͤ��Ƥ�����
    (t
     (incf collision-count)))
   ;;
   ;;2��ʾ�֤Ĥ��äƤ���֤ΰ�ư��������ʤ���ʾ�Ϥ�ꤳ�ޤ��ʤ�����)
   (when (> collision-count 1)
     (let* ((diff-x (* -2.0 (aref wheel-velocity-vector 0) tick-time 0.001))
	    (diff-y (* -2.0 (aref wheel-velocity-vector 1) tick-time 0.001))
	    (diff-rot (* -2.0 (aref wheel-velocity-vector 2) tick-time 0.001)))
       (send robot :move (float-vector diff-x diff-y diff-rot)))
     ;;(decf collision-count)
     ;;(print collision-count)
     (setq collision-count 0)
     )
   )
  ;;
  ;;��֤ؤ�interface (����ϡ�robot-client������Ʊ���ˤ���ɬ�פ���)
  ;; <for wheel>
  ;; 
  ;; ��������⡼�ɤ��ѹ� wheel-controlmode-vector
  ;;   PWM����:0, ®������:1, Ĺ������: 2, ����OFF:-1
  ;;   Ex. (send *rs* :wheel-controlmode-vector #f(1 1 1)) 
  (:wheel-controlmode-vector
   (ctrl-vector)
   (setq wheel-controlmode-vector ctrl-vector)
   nil)
  (:wheel-angle-vector
   (angle-vector &optional (time 1000))
   (warn "Sorry, no implementation in robot-server-simulation~%"))
  (:wheel-velocity-vector
   (vel-vector)
   (warn "Sorry, no implementation in robot-server-simulation~%"))
  ;;�������(servo-off����, encoder=0, �Ƽ���ɸ��0)���᤹
  (:wheel-reset 
   ()
   (setq wheel-controlmode-vector (float-vector *VELOCITY_CONTROL* *VELOCITY_CONTROL* *VELOCITY_CONTROL*))
   (setq wheel-velocity-vector #f(0 0 0))
   )
  ;;��֤���ɸxy®�١���ɸ��®��[deg]/sec��Ϳ����
  (:daisya-velocity-vector 
   (daisyavel-vector)
   (cond 
    ;;���ؤ�®������ˤʤäƤ���Ȥ��Τ�ȿ�Ǥ���褦�ˤ���
    ((and (= (aref wheel-controlmode-vector 0) *VELOCITY_CONTROL*)
	  (= (aref wheel-controlmode-vector 1) *VELOCITY_CONTROL*)
	  (= (aref wheel-controlmode-vector 2) *VELOCITY_CONTROL*))
     (setq wheel-velocity-vector daisyavel-vector))
    ;;����ʳ��ξ��ϥ��顼���֤�
    (t
     (warn "daisya-velocity-vector can be done with all wheels under velocity control~%")
     )))
  ;;��֤�����⡼�ɤ��ѹ�����
  (:daisya-controlmode
   (cm)
   (setq daisya-controlmode cm)
   )
  ;;��֤ΰ���������������
  (:daisya-position-vector
   (daisyapos-vector &optional (time 1000))
   (dotimes (i 3) (setf (aref daisya-prev-posvector i) 0))
   ;;���ߤ���ִ���ꤲ��
   (send daisya-current-interpolator
	 :reset
	 :angle-vector-list
	 (list (float-vector 0 0 0) daisyapos-vector)
	 :step-list
	 (list (/ time tick-time) (/ time tick-time)))
   (send daisya-current-interpolator :start-interpolation)
   nil)
  ;;
  ;; for arm(servo)
  ;;
  ;;(send *rs* :arm-poweron-vector #f(0 0 0 0 0))��OFF
  ;;(send *rs* :arm-poweron-vector #f(1 1 1 1 1))��ON
  (:arm-poweron-vector
   (armpon-vector)
   (setq arm-poweron-vector armpon-vector)
   nil)
  (:arm-interpolation-method
   (im)
   (setq arm-interpolation-method im)
   (print arm-interpolation-method)
   (cond 
    ((= arm-interpolation-method *INTERPOLATE_LINEAR* )
     (warn "change linear~%")
     (setq arm-current-interpolator arm-linear-interpolator))
    ((= arm-interpolation-method *INTERPOLATE_MINJERK* )
     (warn "change minjerk~%")
     (setq arm-current-interpolator arm-minjerk-interpolator))
    (t
     (warn "no such interpolation method~%")))
   nil)
  (:arm-angle-vector
   (angle-vector &optional (time 1000))
   ;;���ߤ���ִ���ꤲ��
   (send arm-current-interpolator 
	 :reset
	 :angle-vector-list 
	 (list (send robot :angle-vector) angle-vector)
	 :step-list
	 (list (/ time tick-time) (/ time tick-time)))
   (send arm-current-interpolator :start-interpolation)
   nil)
  ;;
  ;; robotstate�μ��� (����ӳƼ糧�󥵤�accessor)
  (:get-robot-state
   nil
   (warn "Sorry, no implementation in robot-server-simulation~%"))
  (:get-wheels-angle 
   () 
   (warn "Sorry, no implementation in robot-server-simulation~%"))
  (:get-wheels-controlmode () wheel-controlmode-vector)
  (:bumper-vector 
   () 
   (send robot :bumper-vector))
  (:psd-vector 
   () 
   (send robot :psd-vector))
  (:camera-vector
   ()
   (send robot :camera-vector))
  )