If (FORM Event.code=On Clicked)
	If (Form.zonePicker.index>=0)
		Form.zone:=Form.zonePicker.currentValue
		Form.convertCurrent()
	End if
End if
