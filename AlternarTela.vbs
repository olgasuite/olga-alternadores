' Abre o AlternarTela.ps1 sem janela do PowerShell
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Scripts\AlternarTela.ps1""", 0, False
