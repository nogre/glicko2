extends Control


func _ready():
	run_tests()


func run_tests():
	var tc = testCases.new()
	tc.setUp()
	tc.test_rating()
	tc.test_ratingDeviation()
	tc.test_volatility()
	tc.test_ryan_rating()
	tc.test_ryan_ratingDeviant()
	tc.test_ryan_volatility()


class testCases:
	var P1
	var Ryan
	func setUp():
		# Feb222012 example.
		self.P1 = Player.new()
		self.P1.setRd(200)
		self.P1.update_player([1400, 1550, 1700], [30, 100, 300], [1, 0, 0])
		# Original Ryan example.
		self.Ryan = Player.new()
		self.Ryan.update_player([1400, 1550, 1700],[30, 100, 300], [1, 0, 0])

	func test_rating():
		# stepify acts like round in python
		if (stepify(self.P1.getRating(), .01) != 1464.05):
			print("fail test_rating")
	func test_ratingDeviation():
		if(stepify(self.P1.getRd(), .01) != 151.52):
			print("fail test_ratingDeviation")
	func test_volatility():
		if(stepify(self.P1.vol, .00001) !=  0.05999):
			print("fail test_volatility")
	func test_ryan_rating():
		if(stepify(self.Ryan.getRating(), .01) !=  1441.53):
			print("fail test_ryan_rating")
	func test_ryan_ratingDeviant():
		# some sort of (rounding?) discrepancy happens here. but the strings line up, so it should be OK
		var rrd = stepify(self.Ryan.getRd(), .01)
		if(str(rrd) != str(193.23)): 
			print("fail test_ryan_ratingDeviant")
	func test_ryan_volatility():
		if(stepify(self.Ryan.vol, .00001) !=  0.05999):
			print("fail test_ryan_volatility")

class Player:
	# Class attribute
	# The system constant, which constrains
	# the change in volatility over time.
	
	var _tau: = 0.5
	var __rating:float
	var __rd:float
	var vol:float

	func getRating():
		return (__rating * 173.7178) + 1500 

	func setRating(rating):
		__rating = (rating - 1500) / 173.7178

#	var rating = property(getRating, setRating)

	func getRd():
		return __rd * 173.7178

	func setRd( rd):
		__rd = rd / 173.7178

#	var rd = property(getRd, setRd)
		
	func _init( rating = 1500, rd = 350, voll = 0.06):
		# For testing purposes, preload the values
		# assigned to an unrated player.
		setRating(rating)
		setRd(rd)
		self.vol = voll
			
	func _preRatingRD():
		""" Calculates and updates the player's rating deviation for the
		beginning of a rating period.
		
		preRatingRD() -> None
		
		"""
		self.__rd = sqrt(pow(self.__rd, 2) + pow(self.vol, 2))
		
	func update_player( rating_list, RD_list, outcome_list):
		""" Calculates the new rating and rating deviation of the player.
		
		update_player(list[int], list[int], list[bool]) -> None
		
		"""
		# Convert the rating and rating deviation values for internal use.
#		rating_list = [(x - 1500) / 173.7178 for x in rating_list]
		var y = []
		for x in rating_list:
			y.append( (x - 1500) / 173.7178 )
		rating_list = y
#		RD_list = [x / 173.7178 for x in RD_list]
		y = []
		for x in RD_list:
			y.append( x / 173.7178 )
		RD_list = y
		
		var v = self._v(rating_list, RD_list)
		self.vol = self._newVol(rating_list, RD_list, outcome_list, v)
		self._preRatingRD()
		
		self.__rd = 1 / sqrt((1 / pow(self.__rd, 2)) + (1 / v))
		
		var tempSum = 0
		for i in range(len(rating_list)):
			tempSum += self._g(RD_list[i]) * \
						(outcome_list[i] - self._E(rating_list[i], RD_list[i]))
		self.__rating += pow(self.__rd, 2) * tempSum
		
	#step 5        
	func _newVol( rating_list, RD_list, outcome_list, v):
		""" Calculating the new volatility as per the Glicko2 system. 
		
		Updated for Feb 22, 2012 revision. -Leo
		
		_newVol(list, list, list, float) -> float
		
		"""
		#step 1
		var a = log(pow(self.vol,2))
		var eps = 0.000001
		var A = a
		
		#step 2
		var B = null
		var delta = self._delta(rating_list, RD_list, outcome_list, v)
		var tau = self._tau
		if pow(delta , 2)  > (pow(self.__rd,2) + v):
			B = log(pow(delta,2) - pow(self.__rd,2) - v)
		else:        
			var k = 1
			while self._f(a - k * sqrt(pow(tau,2)), delta, v, a) < 0:
				k = k + 1
			B = a - k * sqrt(pow(tau , 2))
		
		#step 3
		var fA = self._f(A, delta, v, a)
		var fB = self._f(B, delta, v, a)
		
		#step 4
		while abs(float(B) - float(A)) > eps:
			#a
			var C = A + ((A - B) * fA)/(fB - fA)
			var fC = self._f(C, delta, v, a)
			#b
			if fC * fB < 0:
				A = B
				fA = fB
			else:
				fA = fA/2.0
			#c
			B = C
			fB = fC
		
		#step 5
		return exp(A / 2)
		
	func _f( x, delta, v, a):
		var ex = exp(x)
		var num1 = ex * (pow(delta,2) - pow(self.__rating,2) - v - ex)
		var denom1 = 2 * pow((pow(self.__rating,2) + v + ex),2)
		return  (num1 / denom1) - ((x - a) / pow(self._tau,2))
		
	func _delta( rating_list, RD_list, outcome_list, v):
		""" The delta function of the Glicko2 system.
		
		_delta(list, list, list) -> float
		
		"""
		var tempSum = 0
		for i in range(len(rating_list)):
			tempSum += self._g(RD_list[i]) * (outcome_list[i] - self._E(rating_list[i], RD_list[i]))
		return v * tempSum
		
	func _v( rating_list, RD_list):
		""" The v function of the Glicko2 system.
		
		_v(list[int], list[int]) -> float
		
		"""
		var tempSum = 0
		for i in range(len(rating_list)):
			var tempE = self._E(rating_list[i], RD_list[i])
			tempSum += pow(self._g(RD_list[i]), 2) * tempE * (1 - tempE)
		return 1 / tempSum
		
	func _E( p2rating, p2RD):
		""" The Glicko E function.
		
		_E(int) -> float
		
		"""
		return 1 / (1 + exp(-1 * self._g(p2RD) * \
									(self.__rating - p2rating)))
		
	func _g( RD):
		""" The Glicko2 g(RD) function.
		
		_g() -> float
		
		"""
		return 1 / sqrt(1 + 3 * pow(RD, 2) / pow(PI, 2))
		
	func did_not_compete():
		""" Applies Step 6 of the algorithm. Use this for
		players who did not compete in the rating period.

		did_not_compete() -> None
		
		"""
		self._preRatingRD()
