$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module 
$PSModuleRoot = $PSModule.ModuleBase
#region Custom Object
Write-Verbose "Creating custom RSJob object"
Add-Type -TypeDefinition @"
    using System;

    namespace PoshRS.PowerShell
    {
        public class RSJob
        {
            public string Name;
            public int ID;
            public System.Management.Automation.PSInvocationState State;
            public System.Guid InstanceID;
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
            public bool HasMoreData;
            public bool HasErrors;
            public object Output;
            public System.Guid RunspacePoolID;
            public bool Completed = false;
            public string Batch;
        }
        public class RSRunspacePool
        {
            public System.Management.Automation.Runspaces.RunspacePool RunspacePool;
            public System.Management.Automation.Runspaces.RunspacePoolState State;
            public int AvailableJobs;
            public int MaxJobs;
            public DateTime LastActivity = DateTime.MinValue;
            public System.Guid RunspacePoolID;
            public bool CanDispose = false;
        }
        public class V2UsingVariable
        {
            public string Name;
            public string NewName;
            public object Value;
            public string NewVarName;
        }
    }
"@ -Language CSharp
#endregion Custom Object

#region RSJob Collections
Write-Verbose "Creating RS collections"
New-Variable Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable JobCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
New-Variable JobID -Value ([int64]0) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
#endregion RSJob Collections

#region Cleanup Routine
Write-Verbose "Creating routine to monitor RS jobs"
$jobCleanup.Flag=$True
$jobCleanup.Host = $Host
$jobcleanup.Runspace =[runspacefactory]::CreateRunspace()   
$jobcleanup.Runspace.Open()         
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {   
        [System.Threading.Monitor]::Enter($Jobs.syncroot) 
        Foreach($job in $jobs) {
            $job.state = $job.InnerJob.InvocationStateInfo.State
            If ($job.Handle.isCompleted -AND (-NOT $Job.Completed)) {   
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) completed")  
                Try {           
                    $Data = $job.InnerJob.EndInvoke($job.Handle)
                } Catch {
                    $CaughtErrors = $Error
                    #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Caught terminating Error in job: $_") 
                }
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Checking for errors") 
                If ($job.InnerJob.Streams.Error -OR $CaughtErrors) {
                    #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Errors Found!")
                    $ErrorList = New-Object System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]
                    If ($job.InnerJob.Streams.Error) {
                        ForEach ($Err in $job.InnerJob.Streams.Error) {
                            #$jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")             
                            [void]$ErrorList.Add($Err)
                        }
                    }
                    If ($CaughtErrors) {
                        ForEach ($Err in $CaughtErrors) {
                            #$jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")             
                            [void]$ErrorList.Add($Err)
                        }                    
                    }
                    $job.Error = $ErrorList
                }
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Disposing job")
                $job.InnerJob.dispose() 
                $job.Completed = $True  
                #Return type from Invoke() is a generic collection; need to verify the first index is not NULL
                If (($Data.Count -gt 0) -AND (-NOT ($Null -eq $Data[0]))) {   
                    $job.output = $Data
                    $job.HasMoreData = $True                            
                }              
                $Error.Clear()
            } 
        }        
        [System.Threading.Monitor]::Exit($Jobs.syncroot)
        Start-Sleep -Milliseconds 100     
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $jobcleanup.Runspace
$jobCleanup.Handle = $jobCleanup.PowerShell.BeginInvoke()  

Write-Verbose "Creating routine to monitor Runspace Pools"
$RunspacePoolCleanup.Flag=$True
$RunspacePoolCleanup.Host=$Host
#5 minute timeout for unused runspace pools
$RunspacePoolCleanup.Timeout = [timespan]::FromMinutes(1).Ticks
$RunspacePoolCleanup.Runspace =[runspacefactory]::CreateRunspace()
 
#Create Type Collection so the object will work properly 
$Types = Get-ChildItem "$($PSScriptRoot)\TypeData" -Filter *Types* | Select -ExpandProperty Fullname 
$Types | ForEach { 
    $TypeEntry = New-Object System.Management.Automation.Runspaces.TypeConfigurationEntry -ArgumentList $_ 
    $RunspacePoolCleanup.Runspace.RunspaceConfiguration.types.Append($TypeEntry) 
} 
  
$RunspacePoolCleanup.Runspace.Open()         
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePoolCleanup",$RunspacePoolCleanup)     
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePools",$RunspacePools) 
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("ParentHost",$Host) 
$RunspacePoolCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do { 
        $DisposeRunspacePools=$False  
        If ($RunspacePools.Count -gt 0) { 
            #$ParentHost.ui.WriteVerboseLine("$($RunspacePools | Out-String)")           
            [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
            Foreach($RunspacePool in $RunspacePools) {                
                #$ParentHost.ui.WriteVerboseLine("RunspacePool <$($RunspacePool.RunspaceID)> | MaxJobs: $($RunspacePool.MaxJobs) | AvailJobs: $($RunspacePool.AvailableJobs)")
                If (($RunspacePool.AvailableJobs -eq $RunspacePool.MaxJobs) -AND $RunspacePools.LastActivity.Ticks -ne 0) {
                    If ((Get-Date).Ticks - $RunspacePool.LastActivity.Ticks -gt $RunspacePoolCleanup.Timeout) {
                        #Dispose of runspace pool
                        $RunspacePool.RunspacePool.Close()
                        $RunspacePool.RunspacePool.Dispose()
                        $RunspacePool.CanDispose = $True
                        $DisposeRunspacePools=$True
                    }
                } Else {
                    $RunspacePool.LastActivity = (Get-Date)
                }               
            }       
            #Remove runspace pools
            If ($DisposeRunspacePools) {
                $TempCollection = $RunspacePools.Clone()
                $TempCollection | Where {
                    $_.CanDispose
                } | ForEach {
                    #$ParentHost.ui.WriteVerboseLine("Removing runspacepool <$($_.RunspaceID)>")
                    [void]$RunspacePools.Remove($_)
                }
            }
            Remove-Variable TempCollection
            [System.Threading.Monitor]::Exit($RunspacePools.syncroot)
        }
        Start-Sleep -Milliseconds 5000     
    } while ($RunspacePoolCleanup.Flag)
})
$RunspacePoolCleanup.PowerShell.Runspace = $RunspacePoolCleanup.Runspace
$RunspacePoolCleanup.Handle = $RunspacePoolCleanup.PowerShell.BeginInvoke() 
#endregion Cleanup Routine

#region Load Public Functions
Try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select -Expand FullName | ForEach {
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
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select -Expand FullName | ForEach {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#endregion Load Private Functions

#region Format and Type Data
Update-FormatData "$ScriptPath\TypeData\PoshRSJob.Format.ps1xml"
Update-TypeData "$ScriptPath\TypeData\PoshRSJob.Types.ps1xml"
#endregion Format and Type Data

#region Aliases
New-Alias -Name ssj -Value Start-RSJob
New-Alias -Name gsj -Value Get-RSJob
New-Alias -Name rsj -Value Receive-RSJob
New-Alias -Name rmsj -Value Remove-RSJob
New-Alias -Name spsj -Value Stop-RSJob
New-Alias -Name wsj -Value Wait-RSJob
#endregion Aliases

#region Handle Module Removal
$ExecutionContext.SessionState.Module.OnRemove ={
    $jobCleanup.Flag=$False
    $RunspacePoolCleanup.Flag=$False
    #Let sit for a second to make sure it has had time to stop
    Start-Sleep -Seconds 1
    $jobCleanup.PowerShell.EndInvoke($jobCleanup.Handle)
    $jobCleanup.PowerShell.Dispose()    
    $RunspacePoolCleanup.PowerShell.EndInvoke($RunspacePoolCleanup.Handle)
    $RunspacePoolCleanup.PowerShell.Dispose()
    Remove-Variable JobId -Scope Global -Force
    Remove-Variable Jobs -Scope Global -Force
    Remove-Variable JobCleanup -Scope Global -Force
    Remove-Variable RunspacePoolCleanup -Scope Global -Force
    Remove-Variable RunspacePools -Scope Global -Force
}
#endregion Handle Module Removal

Export-ModuleMember -Alias * -Function '*-RSJob'
