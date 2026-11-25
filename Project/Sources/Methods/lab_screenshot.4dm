//%attributes = {"invisible":true}
// CLI endpoint for the "Lab" form when it declares a formClass.
// Usage: --startup-method lab_screenshot --user-param "Lab:Page:/path/to/output.png"
// Unlike dialog_screenshot, this passes the class instance as the form data, so
// Form.convertCurrent() in the On Load handler resolves to the real method.
ON ERR CALL("Demo_LogError"; ek local)

var $userParamValue : Text
var $unused : Real
$unused:=Get database parameter(User param value; $userParamValue)

var $params : Collection
$params:=Split string($userParamValue; ":")

If ($params.length<3)
	QUIT 4D
	return 
End if 

var $lab : cs.TimeLab
$lab:=cs.TimeLab.new()
$lab.__page:=Num($params[1])
If ($lab.__page<1)
	$lab.__page:=1
End if 
$lab.__screenshotPath:=$params.slice(2).join(":")

var $window : Integer
$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
DIALOG("Lab"; $lab; *)

CALL FORM($window; Formula(goto_page_then_screenshot))
