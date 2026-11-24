' Abre o EjetarDisco.ps1 sem janela do PowerShell
' Com argumento (ex.: "E:\", vindo do menu de contexto do disco): ejeta direto esse disco
Dim extra : extra = ""
If WScript.Arguments.Count > 0 Then extra = " -Letra """ & Left(WScript.Arguments(0), 1) & """"
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Scripts\EjetarDisco.ps1""" & extra, 0, False
