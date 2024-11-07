'
'    install_flow.vbs
'
' (c)2018, J. op den Brouw <J.E.J.opdenBrouw@hhs.nl>
'
' This program installs the INLDIG flow file into the user's profile folder
'

' Warn if undefined variables
Option Explicit

' Constants for file manipulation
Const fsoForReading = 1
Const fsoForWriting = 2
Const fsoForAppending = 8

' Declare variables
Dim startsimfilename
Dim objWSHshell
Dim userProfileFolder
Dim fso
Dim currentFolderName
Dim flowFileName
Dim objFile
Dim oldContent
Dim newContent
Dim result

' The script to start from the flow
startsimfilename = "start_sim.tcl"
' The flow file
flowFileName = "tmwc_BDF_Conversion_And_Simulation.tmf"

' Find user profile folder
Set objWSHshell = WScript.CreateObject( "WScript.Shell" )
userProfileFolder = objWSHshell.ExpandEnvironmentStrings( "%USERPROFILE%" )

'Wscript.Echo "The user profile folder is " & userProfileFolder & vbCrLf & "Press OK to continue"

' Find current folder
Set fso = CreateObject("Scripting.FileSystemObject")
currentFolderName = fso.GetParentFolderName(WScript.ScriptFullName)

' Check if script file exists, bail out if not
If not fso.FileExists(fso.BuildPath(currentFolderName, startsimfilename)) Then
  MsgBox "Missing " & startsimfilename & "! Cannot continue!" & vbCrLf & "Press OK to stop execution", vbCritical, "ERROR!"
  Wscript.Quit
End If

' Check if flow file exists, bail out if not
If not fso.FileExists(fso.BuildPath(currentFolderName, flowFileName)) Then
  MsgBox "Missing " & flowFileName & "! Cannot continue!" & vbCrLf & "Press OK to stop execution", vbCritical, "ERROR!"
  Wscript.Quit
End If

'MsgBox "File " & startsimfilename & " exists in current folder." & vbCrLf & "Press OK to continue", vbOKOnly, "Copying scripts for INLDIG"

'Read in flow file
set objFile=fso.OpenTextFile(fso.BuildPath(currentFolderName, flowFileName), fsoForReading)
oldContent=objFile.ReadAll
objFile.Close 
'MsgBox oldContent

' Now change all \ for / ...
currentFolderName = Replace(currentFolderName, "\", "/")
'Wscript.Echo "The current folder is " & currentFolderName & vbCrLf & "Press OK to continue"

' Replace default path name with new path name
newContent=replace(oldContent,"H:/QUARTUS/common/" & startsimfilename, chr(34) & currentFolderName & "/" & startsimfilename & chr(34) ,1,-1,0)
'MsgBox newContent

' Give the user the option to continue the installation or to abort
result = MsgBox ("Ready to install the flow file in the user's profile folder." & vbCrLf & "Press OK to continue, Cancel to cancel.", vbOKCancel, "Install scripts for Quartus INLDIG flow")
If result = vbCancel Then
  MsgBox "Cancelling installation", vbOKOnly, "Cancel pressed"
  Wscript.Quit
End If

' Trap any errors
Err.Clear
On Error Resume Next

'Write flow file to user profile folder
set objFile=fso.OpenTextFile(fso.BuildPath(userProfileFolder, flowFileName), fsoForWriting, true)
If Err.Number <> 0 Then
  MsgBox "Could not open flow file for writing!" & vbCrLf & "Press OK to stop execution", vbCritical, "ERROR!"
  Wscript.Quit
End If
Err.Clear
objFile.Write newContent
If Err.Number <> 0 Then
  MsgBox "Could not write the content to the flow file!" & vbCrLf & "Press OK to stop execution", vbCritical, "ERROR!"
  Wscript.Quit
End If
objFile.Close
Err.Clear

' Give the user visual feedback
MsgBox "Installed the flow file in the user's profile folder." & vbCrLf & "Press OK to end the installation.", vbOKOnly, "Install scripts for Quartus INLDIG flow"

