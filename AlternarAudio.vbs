' Abre o AlternarAudio.ps1 sem janela do PowerShell
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Scripts\AlternarAudio.ps1""", 0, False
