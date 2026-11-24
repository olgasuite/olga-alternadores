' Abre o TaxaTela.ps1 sem janela do PowerShell
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Scripts\TaxaTela.ps1""", 0, False
