
Set shell = CreateObject("WScript.Shell")
scriptPath = Replace(WScript.ScriptFullName, "Start-ZapretTray.vbs", "ZapretTray.ps1")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""& '" & Replace(scriptPath, "'", "''") & "'"""
shell.Run command, 0, False

