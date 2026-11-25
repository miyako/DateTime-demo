/* TimeLab — the demo's view model.
   It owns one cs.DateTime.DateTime instance (a dependency-manager component),
   builds the interactive state for the "Lab" form, and keeps every displayed
   fact traceable to an actual component response. */

property instant : Text
property zone : Text
property local : Text
property offsetText : Text
property statusText : Text
property statusKind : Text
property statusDetail : Text
property raw : Text
property protocol : Integer
property exitCode : Integer
property elapsedMs : Integer
property rows : Collection
property selectedRow : Object
property selectedRowPos : Integer
property zonePicker : Object
property batchNote : Text
property rulesText : Text
property envDetail : Text
property componentLine : Text
property tool : cs.DateTime.DateTime
property target : Text
property _selfTestDone : Boolean
property __page : Integer
property __screenshotPath : Text

Class constructor
	This.instant:="2026-01-15T12:00:00.123Z"
	This.zone:="Asia/Kathmandu"
	This.local:="—"
	This.offsetText:="—"
	This.statusText:="Ready"
	This.statusKind:=""
	This.statusDetail:=""
	This.raw:=""
	This.protocol:=0
	This.exitCode:=-1
	This.elapsedMs:=0
	This.rows:=New collection
	This.selectedRow:=New object
	This.selectedRowPos:=0
	This.batchNote:="No batch yet — press “Load demo batch”."
	This.target:="macOS-universal"
	If (Is Windows)
		This.target:="Windows-x64"
	End if
	This._selfTestDone:=False
	This.zonePicker:=New object("values"; This.zones(); "index"; 0; "currentValue"; "")
	This.envDetail:=""
	This.rulesText:=This.buildRules()
	This.tool:=cs.DateTime.DateTime.new(This.target)
	This.componentLine:=This.describeVersion()

Function buildRules() : Text
	var $rules : Collection
	var $text : Text
	$rules:=New collection( \
		"Strict RFC3339 in: uppercase T and Z, an explicit offset, at most three fraction digits. Nothing is guessed and nothing is truncated."; \
		"Exact, case-sensitive IANA zone ids from the pinned dataset. No “GMT+05:45”-style offsets and no silent fallback to UTC."; \
		"Historical offsets keep their second precision: Monrovia in 1920 is −00:44:30, not a rounded hour."; \
		"Future conversions use the embedded ICU rules as of the pinned release; a future DST law change is not promised."; \
		"One batch is one process call: the outer result can be ok while individual items fail — inspect every item."; \
		"Failures are reported, not invented: a single rejection has empty stdout, a JSON diagnostic on stderr and exit code 2."; \
		"Bounds are explicit — 35 characters per instant, 64 per zone, 256 items and 30,000 quoted characters per batch."; \
		"Instant → zone only. Resolving a local civil time back to an instant (DST gaps and overlaps) is deliberately out of scope.")
	$text:=""
	var $rule : Text
	For each ($rule; $rules)
		If ($text#"")
			$text:=$text+Char(13)+Char(13)
		End if 
		$text:=$text+"•  "+$rule
	End for each 
	return $text

Function zones() : Collection
	var $zones : Collection
	$zones:=New collection( \
		"UTC"; "Europe/London"; "Europe/Paris"; "Europe/Berlin"; "Europe/Amsterdam"; \
		"Europe/Athens"; "Europe/Moscow"; "Africa/Cairo"; "Africa/Monrovia"; "Africa/Lagos"; \
		"Asia/Jerusalem"; "Asia/Dubai"; "Asia/Karachi"; "Asia/Kathmandu"; "Asia/Kolkata"; \
		"Asia/Dhaka"; "Asia/Bangkok"; "Asia/Shanghai"; "Asia/Tokyo"; "Asia/Seoul"; \
		"Australia/Sydney"; "Australia/Adelaide"; "Pacific/Auckland"; "Pacific/Kiritimati"; \
		"America/St_Johns"; "America/New_York"; "America/Chicago"; "America/Denver"; \
		"America/Los_Angeles"; "America/Sao_Paulo")
	return $zones

Function describeVersion() : Text
	var $version : Object
	var $line : Text
	$line:="component unavailable"
	$version:=This.tool.version()
	If ($version.ok)
		$line:="miyako/DateTime "+$version.value.version+" · protocol "+String($version.value.protocol)+" · "+This.target
	Else
		$line:="miyako/DateTime · version() failed: "+This.errorCode($version)
	End if
	return $line

Function parseJson($text : Text) : Variant
	var $payload : Variant
	var $previous : Text
	$payload:=Null
	$previous:=Method called on error(ek local)
	ON ERR CALL("Demo_IgnoreError"; ek local)
	$payload:=JSON Parse($text)
	ON ERR CALL($previous; ek local)
	return $payload

Function errorCode($result : Object) : Text
	// "invalid_instant" for the headline, with the human message in the detail.
	var $code; $message : Text
	var $payload : Variant
	$code:="unknown error"
	$message:=""
	If (Value type($result)=Is object)
		If (Value type($result.error)=Is object)
			If (Value type($result.error.code)=Is text)
				$code:=$result.error.code
			End if
			If (Value type($result.error.message)=Is text)
				$message:=$result.error.message
			End if
		End if
	End if
	If ($code="cli_error")
		// The native binary reports semantic failures as JSON on stderr.
		$payload:=This.parseJson($message)
		If (Value type($payload)=Is object) && (Value type($payload.error)=Is object)
			If (Value type($payload.error.code)=Is text)
				$code:=$payload.error.code
			End if
			If (Value type($payload.error.message)=Is text)
				$message:=$payload.error.message
			End if
		End if
	End if
	If (($message#"") && ($message#$code))
		return $code+" — "+$message
	End if
	return $code

Function errorSummary($result : Object) : Text
	var $full : Text
	$full:=This.errorCode($result)
	var $cut : Integer
	$cut:=Position(" — "; $full)
	If ($cut>0)
		return Substring($full; 1; $cut-1)
	End if
	return $full

Function offsetLabel($seconds : Integer) : Text
	var $sign : Text
	var $absolute : Integer
	var $hours; $minutes; $rest : Integer
	var $label : Text
	$sign:="+"
	$absolute:=$seconds
	If ($absolute<0)
		$sign:="-"
		$absolute:=-$absolute
	End if
	$hours:=$absolute\3600
	$minutes:=($absolute%3600)\60
	$rest:=$absolute%60
	$label:=$sign+String($hours; "00")+":"+String($minutes; "00")
	If ($rest#0)
		$label:=$label+":"+String($rest; "00")
	End if
	return $label

Function clockOf($localText : Text) : Text
	// "2026-01-15T17:45:00.123+05:45" -> "17:45:00.123"
	var $clock : Text
	$clock:=$localText
	If (Length($clock)>19)
		$clock:=Substring($clock; 12; 12)
	End if
	return $clock

Function convertCurrent()
	var $started : Integer
	var $result : Object
	$started:=Milliseconds
	$result:=This.tool.convert(This.instant; This.zone)
	This.elapsedMs:=Milliseconds-$started
	This.applyResult($result)

Function applyResult($result : Object)
	This.protocol:=0
	This.exitCode:=-1
	This.raw:=""
	If (Value type($result)#Is object)
		This.statusKind:="error"
		This.statusText:="✖ Unusable result"
		This.statusDetail:="the adapter returned no Object"
		return 
	End if
	If (Value type($result.exitCode)=Is real) || (Value type($result.exitCode)=Is longint)
		This.exitCode:=$result.exitCode
	End if
	// Evidence policy: keep the machine-readable stream the component used.
	If ((Value type($result.stdout)=Is text) && ($result.stdout#""))
		This.raw:=$result.stdout
	Else
		If (Value type($result.stderr)=Is text)
			This.raw:=$result.stderr
		End if
	End if
	If ($result.ok=True)
		This.protocol:=$result.value.protocol
		This.local:=$result.value.local
		This.offsetText:=This.offsetLabel($result.value.offsetSeconds)+"  ("+String($result.value.offsetSeconds)+" s)"
		This.statusKind:="ok"
		This.statusText:="✔ converted · "+This.clockOf($result.value.local)
		This.statusDetail:=$result.value.zone+" · exit "+String($result.exitCode)+" · "+String(This.elapsedMs)+" ms"
		This.refreshEnv()
	Else
		This.local:="—"
		This.offsetText:="—"
		This.statusKind:="error"
		This.statusText:="✖ "+This.errorSummary($result)
		This.statusDetail:=This.rejectHint()+" · exit "+String(This.exitCode)+" · JSON on stderr"
		This.refreshEnv()
	End if

Function rejectHint() : Text
	var $hint : Text
	$hint:="the CLI rejected the input before producing a value"
	If (Position("t"; This.instant; 1; *)#0) && (Position("T"; This.instant; 1; *)=0)
		$hint:="lowercase “t” is not RFC3339 here — uppercase T and Z are required"
	Else
		If (Position("Z"; This.instant; *)=Length(This.instant))
			$hint:="check the instant: explicit offset, at most 3 fraction digits, a real calendar date"
		End if
	End if
	If (Not(This.zoneExists(This.zone)))
		$hint:="“"+This.zone+"” is not an exact IANA zone id — try the picker"
	End if
	return $hint

Function zoneExists($name : Text) : Boolean
	return (This.zones().indexOf($name)>=0)

Function refreshEnv()
	This.envDetail:="protocol "+String(This.protocol)+" · exitCode "+String(This.exitCode)+" · "+String(This.elapsedMs)+" ms · "+String(This.rows.length)+" batch rows"

Function loadPreset($name : Text)
	Case of 
		: ($name="dst")
			This.instant:="2026-03-29T01:00:00Z"
			This.zone:="Europe/Paris"
			This.convertCurrent()
		: ($name="monrovia")
			This.instant:="1920-06-01T00:00:00Z"
			This.zone:="Africa/Monrovia"
			This.convertCurrent()
		: ($name="kathmandu")
			This.instant:="2026-01-15T12:00:00.123Z"
			This.zone:="Asia/Kathmandu"
			This.convertCurrent()
		: ($name="kiritimati")
			This.instant:="2026-01-15T12:00:00Z"
			This.zone:="Pacific/Kiritimati"
			This.convertCurrent()
		: ($name="lowercase")
			This.instant:="2026-01-15t12:00:00z"
			This.zone:="UTC"
			This.convertCurrent()
		: ($name="fraction")
			This.instant:="2026-01-15T12:00:00.1234Z"
			This.zone:="UTC"
			This.convertCurrent()
		: ($name="unknownzone")
			This.instant:="2026-01-15T12:00:00Z"
			This.zone:="Mars/Olympus"
			This.convertCurrent()
		: ($name="ladder")
			This.loadLadder()
	End case 
	This.refreshEnv()

Function loadLadder()
	var $rows : Collection
	var $zone : Text
	$rows:=New collection
	For each ($zone; This.zones())
		$rows.push(New object("index"; $rows.length+1; "instant"; "2026-01-15T12:00:00Z"; "zone"; $zone; "status"; "pending"; "local"; ""; "offset"; ""; "error"; ""))
	End for each 
	This.rows:=$rows
	This.batchNote:="Offset ladder loaded — press “Run batch”."
	This.runBatch()

Function loadDemoBatch()
	var $rows : Collection
	$rows:=New collection
	$rows.push(New object("index"; 1; "instant"; "2026-07-15T12:00:00Z"; "zone"; "Europe/Paris"))
	$rows.push(New object("index"; 2; "instant"; "2026-07-15T12:00:00Z"; "zone"; "America/St_Johns"))
	$rows.push(New object("index"; 3; "instant"; "2026-07-15T12:00:00Z"; "zone"; "Asia/Kathmandu"))
	$rows.push(New object("index"; 4; "instant"; "bad-instant"; "zone"; "UTC"))
	$rows.push(New object("index"; 5; "instant"; "2026-07-15T12:00:00Z"; "zone"; "Mars/Olympus"))
	$rows.push(New object("index"; 6; "instant"; "2026-02-29T00:00:00Z"; "zone"; "UTC"))
	$rows.push(New object("index"; 7; "instant"; "1920-06-01T00:00:00Z"; "zone"; "Africa/Monrovia"))
	$rows.push(New object("index"; 8; "instant"; "2026-07-15T12:00:00Z"; "zone"; "Pacific/Kiritimati"))
	This.resetRows($rows)
	This.batchNote:="8 rows — 3 are meant to fail, in input order."

Function loadStressBatch()
	var $rows : Collection
	var $zones; $instants : Collection
	var $i : Integer
	$rows:=New collection
	$zones:=This.zones().copy()
	$zones.push("Not/AZone")
	$zones.push("gmt+1")
	$instants:=New collection("2026-01-15T12:00:00Z"; "2026-03-29T00:59:59Z"; "2026-03-29T01:00:00Z"; "2026-10-25T00:59:59Z"; "2026-10-25T01:00:00Z"; "bad-instant"; "2026-12-31T23:59:59.999Z"; "0001-01-01T00:00:00Z")
	For ($i; 1; 256)
		$rows.push(New object("index"; $i; "instant"; $instants[($i-1)%$instants.length]; "zone"; $zones[($i-1)%$zones.length]))
	End for 
	This.resetRows($rows)
	This.batchNote:="256 rows (the transport maximum) — mixed valid and invalid."

Function loadEmptyBatch()
	This.rows:=New collection
	This.selectedRow:=New object
	This.selectedRowPos:=0
	This.batchNote:="Batch cleared."
	This.refreshEnv()

Function resetRows($rows : Collection)
	var $row : Object
	For each ($row; $rows)
		$row.status:="pending"
		$row.local:=""
		$row.offset:=""
		$row.error:=""
	End for each 
	This.rows:=$rows
	This.selectedRow:=New object
	This.selectedRowPos:=0

Function runBatch()
	var $items : Collection
	var $row : Object
	var $result : Object
	var $started : Integer
	var $okCount; $failCount : Integer
	If (This.rows.length<1)
		This.batchNote:="Nothing to run — load a batch first."
		return 
	End if
	If (This.rows.length>256)
		This.batchNote:="The component accepts at most 256 items; this batch has "+String(This.rows.length)+"."
		return 
	End if
	$items:=New collection
	For each ($row; This.rows)
		$items.push(New object("instant"; This.asText($row.instant); "zone"; This.asText($row.zone)))
	End for each 
	$started:=Milliseconds
	$result:=This.tool.convertBatch($items)
	This.elapsedMs:=Milliseconds-$started
	This.protocol:=0
	This.exitCode:=-1
	If (Value type($result.exitCode)=Is real) || (Value type($result.exitCode)=Is longint)
		This.exitCode:=$result.exitCode
	End if
	If ($result.ok=True)
		var $position : Integer
		$okCount:=0
		$failCount:=0
		This.protocol:=$result.value.protocol
		For ($position; 1; This.rows.length)
			$row:=This.rows[$position-1]
			var $entry : Object
			$entry:=$result.value.results[$position-1]
			If ($entry.ok=True)
				$row.status:="ok"
				$row.local:=$entry.value.local
				$row.offset:=This.offsetLabel($entry.value.offsetSeconds)
				$row.error:=""
				$okCount:=$okCount+1
			Else
				$row.status:="error"
				$row.local:="—"
				$row.offset:="—"
				$row.error:=$entry.error.code+" — "+$entry.error.message
				$failCount:=$failCount+1
			End if
		End for 
		This.batchNote:=String(This.rows.length)+" rows · "+String($okCount)+" ok · "+String($failCount)+" item errors · exit "+String(This.exitCode)+" · "+String(This.elapsedMs)+" ms"
		This.statusText:="✔ batch finished in "+String(This.elapsedMs)+" ms"
		This.statusKind:="ok"
	Else
		This.batchNote:="✖ batch rejected: "+This.errorCode($result)
		This.statusText:="✖ batch rejected"
		This.statusKind:="error"
	End if
	This.refreshEnv()
	This.raw:=JSON Stringify($result)

Function asText($value : Variant) : Text
	If (Value type($value)=Is text)
		return $value
	End if
	return ""

Function usePickedRow()
	var $row : Object
	If (This.selectedRowPos<1)
		return 
	End if
	If (This.selectedRowPos>This.rows.length)
		return 
	End if
	$row:=This.rows[This.selectedRowPos-1]
	This.instant:=This.asText($row.instant)
	This.zone:=This.asText($row.zone)
	This.convertCurrent()

Function copyRaw()
	If (This.raw#"")
		SET TEXT TO PASTEBOARD(This.raw)
		This.statusText:="⧉ last JSON on the clipboard"
		This.statusKind:="ok"
	End if

Function selfTest() : Object
	// Drives the same code paths the form uses, without a window.
	var $report : Object
	var $single : Object
	var $dstBefore; $dstAfter : Object
	This._selfTestDone:=True
	This.loadPreset("kathmandu")
	$single:=New object("ok"; This.statusKind="ok"; "local"; This.local; "offset"; This.offsetText; "raw"; This.raw)
	This.instant:="2026-03-29T00:59:59Z"
	This.zone:="Europe/Paris"
	This.convertCurrent()
	$dstBefore:=New object("offset"; This.offsetText; "local"; This.local)
	This.instant:="2026-03-29T01:00:00Z"
	This.convertCurrent()
	$dstAfter:=New object("offset"; This.offsetText; "local"; This.local)
	This.loadPreset("lowercase")
	var $rejected : Object
	$rejected:=New object("status"; This.statusText; "kind"; This.statusKind; "detail"; This.statusDetail; "exitCode"; This.exitCode; "raw"; This.raw)
	This.loadDemoBatch()
	This.runBatch()
	var $demoBatchNote : Text
	var $demoRaw : Text
	$demoBatchNote:=This.batchNote
	$demoRaw:=This.raw
	var $batchOk; $batchFail : Integer
	var $row : Object
	$batchOk:=0
	$batchFail:=0
	For each ($row; This.rows)
		If ($row.status="ok")
			$batchOk:=$batchOk+1
		Else
			$batchFail:=$batchFail+1
		End if
	End for each 
	This.loadStressBatch()
	This.runBatch()
	var $stressNote : Text
	$stressNote:=This.batchNote
	$report:=New object( \
		"component"; This.componentLine; \
		"target"; This.target; \
		"single"; $single; \
		"dstBefore"; $dstBefore; \
		"dstAfter"; $dstAfter; \
		"rejected"; $rejected; \
		"batchOk"; $batchOk; "batchFail"; $batchFail; "batchNote"; $demoBatchNote; \
		"batchRaw"; $demoRaw; \
		"stressNote"; $stressNote; \
		"stressRows"; This.rows.length; \
		"elapsedMs"; This.elapsedMs; \
		"finished"; True)
	return $report
