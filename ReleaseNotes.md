---------
|1.7.3.11|
---------
* #139 (Wait-RSJob is not working with parameter set Name or ID)
* #140 (Wait-RSJob doesn't sleep)
* #141 (-RSJob question)

---------
|1.7.3.10|
---------
* #139 (Wait-RSJob is not working with parameter set Name or ID.)

---------
|1.7.3.9|
---------
* #42 (V2 Pester test hangs in AppVeyor)
* #121 (Missing output from Start-RSJob *bug*)
* #122 (Output stream is not always cleared when using pooled runspaces)
* #136 (RSJob on PSv2)

---------
|1.7.3.8|
---------
* #133 (Passing synchronized hashtable as argument does not work)
* #132 (Not handling single parameter in ArgumentList correctly)
* #136 (RSJob on PSv2) - Some parts may be fixed with how reflection is used

---------
|1.7.3.7|
---------
* #127 (Module loading failure with high throttle counts (and possibly related skipped jobs))
* #107 (Write-Stream throws lots of spurious errors on missing variables )

---------
|1.7.3.6|
---------
* (FunctionsToLoad doesn't work if a script is called within a script)
* #124 (powershell_ise processes are left around once PoshRSJob module is loaded)

---------
|1.7.3.5|
---------
* #119 (Passing an empty batch to Wait-RSJob stops all further processing in the caller)
* #95 (RSJob State does not reflect actual state of job)
* #111 (Exception calling "BeginInvoke" with "0" argument(s): "Cannot perform the operation because the runspace pool is not in the 'Opened' state. The current state is 'Closed'." )

---------
|1.7.3.3|
---------
* Fixed Issue #116 (v1.7.3.0 is extremely slow)
* Fixed Issue #75 (Feature Request: Add RunspaceID handling to Start-RSJob for better throttling support)
* Fixed Issue #107 (Write-Stream throws lots of spurious errors on missing variables)
* Added some better support for streams with Receive-RSJob

---------
|1.7.3.0|
---------
* Fixed Issue #112 (TabExpansion puts a small error in $error)
* Fixed Issue #115 (Multiple runspaces are being created when running Start-RSJob)

---------
|1.7.2.9|
---------
* Fixed Issue #101 (Wait-RsJob -State Completed with no input returns Attempted to divide by zero.)
* Fixed Issue #108 (Caveats of Start-RSJob -ModulesToImport) - Using ForEach loop with PoshRSJob no longer works with this update due to issues that it brought with -ModulesToImport, -FunctionsToLoad and -PSSnapinsToImport where these would fail due to a runspacepool already being used.

---------
|1.7.2.7|
---------
* Fixed Issue #102 (Receive-RsJob doesn't process -InputObject properly)

---------
|1.7.2.6|
---------
* Fixed Issue #99 (Add an InputObject property to RSJob)

---------
|1.7.2.5|
---------
* Fixed Issue #96 (Error when -FunctionsToLoad parameter is used and the Function does not have an alias)

---------
|1.7.2.4|
---------
* Fixed Issue #92 (Cannot load module in PS4 due to "class" keyword)


---------
|1.7.2.3|
---------
* Fixed Issue #87 (Stop-RSJob gives an error if it has no input)

---------
|1.7.2.2|
---------
* Fixed Issue #59 (Receive-RSJob doesn't clear a job's HasMoreData state)

---------
|1.7.2.1|
---------
* Fixed Issue #83 (FunctionsToImport should include the function's Alias where applicable)


---------
|1.7.1.0|
---------
* Replaced private apis with public apis (#85 Update RunspaceConfiguration apis to use InitialSessionState instead)

---------
|1.7.0.0|
---------
* Remove need for DLL file for building out the classes. Using pure PowerShell (mostly) via means of here-strings and Add-Type for PowerShell V2-4 and the new Classes keywords for PowerShell V5 which includes PowerShell Core/Nano.
* Remove the prefixes for custom objects so they no longer start with PoshRS.PowerShell.. Now they are V2UsingVariable, RSJob and RSRunspacePool.

---------
|1.6.2.1|
---------
* Add support for PowerShell Core on Linux/MacOS (this still needs more work but should load types within a runspace now!)

---------
|1.6.1.0|
---------
* Fixed Issue #75 (Feature Request: Add RunspaceID handling to Start-RSJob for better throttling support)
* Fixed Issue #82 (Exception setting "RunspacePool" in 1.6.0.0 build)

---------
|1.5.7.7|
---------
* Fixed Issue #69 (Module produces error if imported more than once (PS v2 only))
* Fixed Issue #64 (HadErrors in PoshRS.PowerShell.RSJob throws errors in PowerShell V2)
* Fixed Issue #67 (Converted Add-Type code for C# classes to be created via Reflection for Nano server support) <- Created custom dll
* Fixed Issue #61 (Receive-RSJob not allowing -Job parameter input)
* Fixed Issue #63 (Replaced Global variables with Script scope)
* Fixed Issue #66 (Parameters don't work with PowerShell V2)
* Fixed Issue #65 (Bug with v2 variable substitution - single-quoted strings get $var references replaced)
* Fixed Issue #68 (ApartmentState Does Not Exist in Nano)
* Fixed Issue #76 (Jobs don't have output when using ADSI WinNT provider (Receive-RSJob))
