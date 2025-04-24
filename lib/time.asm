TIME_TIMER = 0fb00h
TIME_NOW   = 0fb01h

time_get:
	; #0 = current 
	
	pshb

	lld #TIME_NOW
	st  #0

	ret

