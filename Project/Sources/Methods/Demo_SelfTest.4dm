//%attributes = {"invisible":true}
// Headless driver: exercises the same TimeLab paths the form uses and writes
// a JSON report to the path supplied with --user-param.

var $ignored : Integer
var $path : Text
$path:=""
$ignored:=Get database parameter(User param value; $path)

var $lab : cs.TimeLab
$lab:=cs.TimeLab.new()

var $report : Object
$report:=$lab.selfTest()

If ($path#"")
	var $file : 4D.File
var $made : Boolean
	$file:=File($path)
	$made:=$file.parent.create()
	$file.setText(JSON Stringify($report; *))
End if 

QUIT 4D
