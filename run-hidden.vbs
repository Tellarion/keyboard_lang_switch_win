' Tellarion.dev — Apple Keyboard Lang Switch
' Скрытый запуск lang-switch.ps1 без окна PowerShell

Set args = WScript.Arguments
If args.Count < 2 Then WScript.Quit 1

ps1Path = args(0)
pidFile = args(1)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1Path & """"

Set shell = CreateObject("WScript.Shell")
Set proc = shell.Exec(cmd)

Set fso = CreateObject("Scripting.FileSystemObject")
Set f = fso.CreateTextFile(pidFile, True)
f.Write proc.ProcessID
f.Close
