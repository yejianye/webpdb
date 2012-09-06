function AppCtrl($scope) {
	$scope.frames = [
		"/Users/rye/Documents/webpdb/test.py:main()",
		"/Users/rye/Documents/webpdb/test.py:add()",
	];
	$scope.source = "def add(x, y):\n    import webpdb; webpdb.set_trace()\n    print x+y\n\ndef main():\n    add(1, 2)\nif __name__ == '__main__':\n    main()";
}
