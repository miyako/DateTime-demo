//%attributes = {"invisible":true}
// Diagnostics for headless runs: record the first error to a file.
var $mode : Variant
var $code : Variant
var $text : Variant
$mode:=$1
$code:=$2
$text:=$3
var $file : 4D.File
$file:=File("/tmp/lab-error.log")
$file.parent.create()
TEXT TO DOCUMENT($file.platformPath; String($mode)+" | "+String($code)+" | "+String($text))
