Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """c:\Users\user\Documents\project\VanishLab\.venv\Scripts\pythonw.exe"" ""c:\Users\user\Documents\project\VanishLab\backend\scripts\start_daemon.py""", 0, False
Set WshShell = Nothing
