$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase
If ($PSVersionTable['PSEdition'] -and $PSVersionTable.PSEdition -eq 'Core') {
#PowerShell V4 and below will throw a parser error even if I never use the classes keyword
@'
    class V2UsingVariable {
        [string]$Name
        [string]$NewName
        [object]$Value
        [string]$NewVarName
    }

    class RSRunspacePool{
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
        [System.Management.Automation.Runspaces.RunspacePoolState]$State
        [int]$AvailableJobs
        [int]$MaxJobs
        [DateTime]$LastActivity = [DateTime]::MinValue
        [String]$RunspacePoolID
        [bool]$CanDispose = $False
    }
    class RSJob {
        [string]$Name
        [int]$ID
        [System.Management.Automation.PSInvocationState]$State
        [object]$InputObject
        [string]$InstanceID
        [object]$Handle
        [object]$Runspace
        [System.Management.Automation.PowerShell]$InnerJob
        [System.Threading.ManualResetEvent]$Finished
        [string]$Command
        [System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]]$Error
        [System.Management.Automation.PSDataCollection[System.Management.Automation.VerboseRecord]]$Verbose
        [System.Management.Automation.PSDataCollection[System.Management.Automation.DebugRecord]]$Debug
        [System.Management.Automation.PSDataCollection[System.Management.Automation.WarningRecord]]$Warning
        [System.Management.Automation.PSDataCollection[System.Management.Automation.ProgressRecord]]$Progress
        [bool]$HasMoreData = $True
        [bool]$HasErrors
        [object]$Output
        [string]$RunspacePoolID
        [bool]$Completed = $False
        [string]$Batch
        hidden [bool] $IsReceived = $False

    }
'@ | Invoke-Expression
}
Else {
    Add-Type @"
    using System;
    using System.Collections.Generic;
    using System.Text;
    using System.Management.Automation;

    public class V2UsingVariable
    {
        public string Name;
        public string NewName;
        public object Value;
        public string NewVarName;
    }

    public class RSRunspacePool
    {
        public System.Management.Automation.Runspaces.RunspacePool RunspacePool;
        public System.Management.Automation.Runspaces.RunspacePoolState State;
        public int AvailableJobs;
        public int MaxJobs;
        public DateTime LastActivity = DateTime.MinValue;
        public string RunspacePoolID;
        public bool CanDispose = false;
    }
    public class RSJob
    {
        public string Name;
        public int ID;
        public System.Management.Automation.PSInvocationState State;
        public object InputObject;
        public string InstanceID;
        public object Handle;
        public object Runspace;
        public System.Management.Automation.PowerShell InnerJob;
        public System.Threading.ManualResetEvent Finished;
        public string Command;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.ErrorRecord> Error;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.VerboseRecord> Verbose;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.DebugRecord> Debug;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.WarningRecord> Warning;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.ProgressRecord> Progress;
        public bool HasMoreData = true;
        public bool HasErrors;
        public object Output;
        public string RunspacePoolID;
        public bool Completed = false;
        public string Batch;
        #pragma warning disable 414
        private bool IsReceived = false;
        #pragma warning restore 414
    }
"@
}

#region RSJob Variables
Write-Verbose "Creating RS collections"
New-Variable PoshRS_Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Global -Force
New-Variable PoshRS_jobCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Global -Force
New-Variable PoshRS_JobID -Value ([int64]0) -Option ReadOnly -Scope Global -Force
New-Variable PoshRS_RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Global -Force
New-Variable PoshRS_RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Global -Force
#endregion RSJob Variables

#region Cleanup Routine
Write-Verbose "Creating routine to monitor RS jobs"
$PoshRS_jobCleanup.Flag=$True
$PoshRS_jobCleanup.Host = $Host
$PSModulePath = $env:PSModulePath
$PoshRS_jobCleanup.Runspace =[runspacefactory]::CreateRunspace()
$PoshRS_jobCleanup.Runspace.Open()
$PoshRS_jobCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_jobCleanup",$PoshRS_jobCleanup)
$PoshRS_jobCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_Jobs",$PoshRS_Jobs)
$PoshRS_jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("Begin Do Loop")
    Do {
        [System.Threading.Monitor]::Enter($PoshRS_Jobs.syncroot)
        try {
            Foreach($job in $PoshRS_Jobs) {
                If ($job.Handle.isCompleted -AND (-NOT $Job.Completed)) {
                    #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) completed")
                    $Data = $null
                    $CaughtErrors = $null
                    Try {
                        $Data = $job.InnerJob.EndInvoke($job.Handle)
                    } Catch {
                        $CaughtErrors = $Error
                        #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Caught terminating Error in job: $_")
                    }
                    #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Checking for errors")
                    If ($job.InnerJob.Streams.Error -OR $CaughtErrors) {
                        #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Errors Found!")
                        $ErrorList = New-Object System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]
                        If ($job.InnerJob.Streams.Error) {
                            ForEach ($Err in $job.InnerJob.Streams.Error) {
                                #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")
                                [void]$ErrorList.Add($Err)
                            }
                        }
                        If ($CaughtErrors) {
                            ForEach ($Err in $CaughtErrors) {
                                #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")
                                [void]$ErrorList.Add($Err)
                            }
                        }
                        $job.Error = $ErrorList
                    }
                    #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Disposing job")
                    $job.InnerJob.dispose()
                    #Return type from Invoke() is a generic collection; need to verify the first index is not NULL
                    If ($Data -and ($Data.Count -gt 0) -AND (-NOT ($Data.Count -eq 1 -AND $Null -eq $Data[0]))) {
                        $job.output = $Data
                        $job.HasMoreData = $True
                    }
                    $Error.Clear()
                    $job.Completed = $True
                }
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($PoshRS_Jobs.syncroot)
        }
        Start-Sleep -Milliseconds 100
    } while ($PoshRS_jobCleanup.Flag)
})
$PoshRS_jobCleanup.PowerShell.Runspace = $PoshRS_jobCleanup.Runspace
$PoshRS_jobCleanup.Handle = $PoshRS_jobCleanup.PowerShell.BeginInvoke()

Write-Verbose "Creating routine to monitor Runspace Pools"
$PoshRS_RunspacePoolCleanup.Flag=$True
$PoshRS_RunspacePoolCleanup.Host=$Host
#2 minute timeout for unused runspace pools
$PoshRS_RunspacePoolCleanup.Timeout = [timespan]::FromMinutes(2).Ticks
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

#Create Type Collection so the object will work properly
$Types = Get-ChildItem "$($PSScriptRoot)\TypeData" -Filter *Types* | Select-Object -ExpandProperty Fullname
ForEach ($Type in $Types) {
    $TypeConfigEntry = New-Object System.Management.Automation.Runspaces.SessionStateTypeEntry -ArgumentList $Type
    $InitialSessionState.Types.Add($TypeConfigEntry)
}
$PoshRS_RunspacePoolCleanup.Runspace =[runspacefactory]::CreateRunspace($InitialSessionState)

$PoshRS_RunspacePoolCleanup.Runspace.Open()
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_RunspacePoolCleanup",$PoshRS_RunspacePoolCleanup)
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_RunspacePools",$PoshRS_RunspacePools)
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("ParentHost",$Host)
$PoshRS_RunspacePoolCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    $DisposePoshRS_RunspacePools=$False
    Do {
        #$ParentHost.ui.WriteVerboseLine("Beginning Do Statement")
        $DisposePoshRS_RunspacePools=$False
        If ($PoshRS_RunspacePools.Count -gt 0) {
            #$ParentHost.ui.WriteVerboseLine("$($PoshRS_RunspacePools | Out-String)")
            [System.Threading.Monitor]::Enter($PoshRS_RunspacePools.syncroot)
            try {
                Foreach($RunspacePool in $PoshRS_RunspacePools) {
                    #$ParentHost.ui.WriteVerboseLine("RunspacePool <$($RunspacePool.RunspacePoolID)> | MaxJobs: $($RunspacePool.MaxJobs) | AvailJobs: $($RunspacePool.AvailableJobs)")
                    If (($RunspacePool.AvailableJobs -eq $RunspacePool.MaxJobs) -AND $PoshRS_RunspacePools.LastActivity.Ticks -ne 0) {
                        If ((Get-Date).Ticks - $RunspacePool.LastActivity.Ticks -gt $PoshRS_RunspacePoolCleanup.Timeout) {
                            #Dispose of runspace pool
                            $RunspacePool.RunspacePool.Dispose()
                            $RunspacePool.CanDispose = $True
                            $DisposePoshRS_RunspacePools=$True
                        }
                    } Else {
                        $RunspacePool.LastActivity = (Get-Date)
                    }
                }
                #Remove runspace pools
                If ($DisposePoshRS_RunspacePools) {
                    $TempCollection = $PoshRS_RunspacePools.Clone()
                    $TempCollection | Where-Object {
                        $_.CanDispose
                    } | ForEach-Object {
                        #$ParentHost.ui.WriteVerboseLine("Removing runspacepool <$($_.RunspacePoolID)>")
                        [void]$PoshRS_RunspacePools.Remove($_)
                    }
                    #Not setting this to silentlycontinue seems to cause another runspace to be created if an error occurs
                    Remove-Variable TempCollection -ErrorAction SilentlyContinue
                    #Perform garbage collection
                    [gc]::Collect()
                }
            }
            finally {
                [System.Threading.Monitor]::Exit($PoshRS_RunspacePools.syncroot)
            }
        }
        #$ParentHost.ui.WriteVerboseLine("Sleeping")
        If ($DisposePoshRS_RunspacePools) {
            #Perform garbage collection
            [gc]::Collect()
        }
        Start-Sleep -Milliseconds 5000
    } while ($PoshRS_RunspacePoolCleanup.Flag)
})
$PoshRS_RunspacePoolCleanup.PowerShell.Runspace = $PoshRS_RunspacePoolCleanup.Runspace
$PoshRS_RunspacePoolCleanup.Handle = $PoshRS_RunspacePoolCleanup.PowerShell.BeginInvoke()
#endregion Cleanup Routine

#region Load Public Functions
Try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#endregion Load Public Functions

#region Load Private Functions
Try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#endregion Load Private Functions

#region Format and Type Data
Try {
    Update-FormatData "$ScriptPath\TypeData\PoshRSJob.Format.ps1xml" -ErrorAction Stop
}
Catch {}
Try {
    Update-TypeData "$ScriptPath\TypeData\PoshRSJob.Types.ps1xml" -ErrorAction Stop
}
Catch {}
#endregion Format and Type Data

#region Aliases
New-Alias -Name ssj -Value Start-RSJob -Force
New-Alias -Name gsj -Value Get-RSJob -Force
New-Alias -Name rsj -Value Receive-RSJob -Force
New-Alias -Name rmsj -Value Remove-RSJob -Force
New-Alias -Name spsj -Value Stop-RSJob -Force
New-Alias -Name wsj -Value Wait-RSJob -Force
#endregion Aliases

#region Handle Module Removal
$PoshRS_OnRemoveScript = {
    $PoshRS_jobCleanup.Flag=$False
    $PoshRS_RunspacePoolCleanup.Flag=$False
    #Let sit for a second to make sure it has had time to stop
    Start-Sleep -Seconds 1
    $PoshRS_jobCleanup.PowerShell.EndInvoke($PoshRS_jobCleanup.Handle)
    $PoshRS_jobCleanup.PowerShell.Dispose()
    $PoshRS_RunspacePoolCleanup.PowerShell.EndInvoke($PoshRS_RunspacePoolCleanup.Handle)
    $PoshRS_RunspacePoolCleanup.PowerShell.Dispose()
    Remove-Variable PoshRS_JobId -Scope Global -Force
    Remove-Variable PoshRS_Jobs -Scope Global -Force
    Remove-Variable PoshRS_jobCleanup -Scope Global -Force
    Remove-Variable PoshRS_RunspacePoolCleanup -Scope Global -Force
    Remove-Variable PoshRS_RunspacePools -Scope Global -Force
}
$ExecutionContext.SessionState.Module.OnRemove += $PoshRS_OnRemoveScript
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $PoshRS_OnRemoveScript
#endregion Handle Module Removal

#region Export Module Members
$ExportModule = @{
    Alias = @('gsj','rmsj','rsj','spsj','ssj','wsj')
    Function = @('Get-RSJob','Receive-RSJob','Remove-RSJob','Start-RSJob','Stop-RSJob','Wait-RSJob')
    Variable = @('PoshRS_JobId','PoshRS_Jobs','PoshRS_jobCleanup','PoshRS_RunspacePoolCleanup','PoshRS_RunspacePools')
}
Export-ModuleMember @ExportModule
#endregion Export Module Members

$env:PSModulePath = $PSModulePath
