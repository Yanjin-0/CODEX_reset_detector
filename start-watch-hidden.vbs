Set shell = CreateObject("WScript.Shell")
scriptPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
command = "powershell -ExecutionPolicy Bypass -File """ & scriptPath & "\watch-codex-reset.ps1"""
shell.Run command, 0, False
