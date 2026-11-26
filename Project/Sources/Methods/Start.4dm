#DECLARE($params : Object)

var $title : Text
var $window : Integer
$title:="DateTime Lab"

If (Count parameters=0)
	
	// Re-running the menu entry brings the existing window to the front.
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	var $i : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=Current process) && (Get window title($window)=$title)
			var $left; $top; $right; $bottom : Integer
			GET WINDOW RECT($left; $top; $right; $bottom; $window)
			SET WINDOW RECT($left; $top; $right; $bottom; $window)
			return 
		End if 
	End for 
	
	CALL WORKER(1; Current method name; {})
	
Else 
	
	SET MENU BAR(1)
	
	var $lab : cs.TimeLab
	$lab:=cs.TimeLab.new()
	
	$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	
	DIALOG("Lab"; $lab; *)
	
End if 
