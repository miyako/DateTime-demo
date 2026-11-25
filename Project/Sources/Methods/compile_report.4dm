//%attributes = {"invisible":true}
// Headless compile probe for the class-store chokepoint.
// Usage: tool4d --project ... --startup-method=compile_report --user-param=/tmp/req.json
// where req.json is {"project":"<abs path to .4DProject>","status":"<abs path to status.json>"}.
// It writes Compile project's raw JSON verdict so the demo can show the exact
// diagnostics instead of guessing from the exit code.
var $ignored : Integer
var $parameter : Text
var $request; $status; $options : Object
var $project; $output : 4D.File
$ignored:=Get database parameter(User param value; $parameter)
$request:=JSON Parse(File($parameter; fk posix path).getText())
$project:=File($request.project; fk posix path)
$output:=File($request.status; fk posix path)
$options:=New object("targets"; New collection("arm64_macOS_lib"); "generateSymbols"; False; "generateSyntaxFile"; True)
$status:=Compile project($project; $options)
$status.project:=$project.path
$status.targets:=$options.targets
$output.setText(JSON Stringify($status))
QUIT 4D
