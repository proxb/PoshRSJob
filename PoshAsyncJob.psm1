#region TODO

#endregion TODO

#region Custom Object
Write-Verbose "Creating custom AsyncJob object"
Add-Type -TypeDefinition @"
    using System;

    namespace PSAsync.PowerShell
    {
        public class AsyncJob
        {
            public string Name;
            public int ID;
            public System.Guid InstanceID;
            public object Handle;
            public object Runspace;
            public System.Management.Automation.PowerShell InnerJob;
            public System.Threading.ManualResetEvent Finished;
            public string Command;
            public System.Management.Automation.ErrorRecord[] Error;
            public System.Management.Automation.VerboseRecord[] Verbose;
            public System.Management.Automation.DebugRecord[] Debug;
            public System.Management.Automation.WarningRecord[] Warning;
            public System.Management.Automation.ProgressRecord[] Progress;
            public bool HasMoreData;
            public bool HasErrors;
            public object Output;
            public System.Guid RunspacePoolID;
        }
        public class AsyncRunspacePool
        {
            public System.Management.Automation.Runspaces.RunspacePool RunspacePool;
            public System.Management.Automation.Runspaces.RunspacePoolState State;
            public int AvailableJobs;
            public int MaxJobs;
            public DateTime LastActivity = DateTime.MinValue;
            public System.Guid RunspacePoolID;
            public bool CanDispose = false;
        }
    }
"@ -Language CSharpVersion3
#endregion Custom Object

#region AsyncJob Collections
Write-Verbose "Creating Async collections"
New-Variable Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable JobCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
New-Variable JobID -Value ([int64]0) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
#endregion AsyncJob Collections

#region Cleanup Routine
Write-Verbose "Creating routine to monitor Async jobs"
$jobCleanup.Flag=$True
$jobcleanup.Runspace =[runspacefactory]::CreateRunspace()   
$jobcleanup.Runspace.Open()         
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {   
        [System.Threading.Monitor]::Enter($Jobs.syncroot) 
        Foreach($job in $jobs) {
            If ($job.Handle.isCompleted) {
                $data = $job.InnerJob.EndInvoke($job.Handle)
                $job.InnerJob.dispose()   
                If ($data) {
                    $job.output = $data
                    $job.HasMoreData = $True
                }                            
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
$RunspacePoolCleanup.Runspace.Open()         
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePoolCleanup",$RunspacePoolCleanup)     
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePools",$RunspacePools) 
$RunspacePoolCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {   
        If ($RunspacePools.Count -gt 0) {            
            [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
            Foreach($RunspacePool in $RunspacePools) {
                If ($RunspacePool.AvailableJobs -ne $RunspacePool.MaxJobs) {
                    If ($RunspacePool.LastActivity -ne [datetime]::MinValue) {
                        If ((Get-Date).Ticks - $RunspacePool.LastActivity.Ticks -gt $RunspacePoolCleanup.Timeout) {
                            #Dispose of runspace pool
                            $RunspacePool.RunspacePool.Close()
                            $RunspacePool.RunspacePool.Dispose()
                            $RunspacePool.CanDispose = $True
                        }
                    } Else {
                        $RunspacePool.LastActivity = (Get-Date)
                    }
                } Else {
                    $RunspacePool.LastActivity = [datetime]::MinValue
                }               
            }        
            #Remove runspace pools
            $TempCollection = $RunspacePools.Clone()
            $TempCollection | Where {
                $_.CanDispose
            } | ForEach {
                [void]$RunspacePools.Remove($_)
            }
            Remove-Variable TempCollection
            [System.Threading.Monitor]::Exit($RunspacePools.syncroot)
        }
        Start-Sleep -Milliseconds 100     
    } while ($RunspacePoolCleanup.Flag)
})
$RunspacePoolCleanup.PowerShell.Runspace = $RunspacePoolCleanup.Runspace
$RunspacePoolCleanup.Handle = $RunspacePoolCleanup.PowerShell.BeginInvoke() 
#endregion Cleanup Routine

#region Load Functions
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
Try {
    Get-ChildItem "$ScriptPath\Scripts" | Select -Expand FullName | ForEach {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#endregion Load Functions

#region Private Functions
Function Increment {
    Set-Variable -Name JobId -Value ($JobId + 1) -Force -Scope Global
    Write-Output $JobId
}
#endregion Private Functions

#region Aliases
New-Alias -Name saj -Value Start-AsyncJob
New-Alias -Name gaj -Value Get-AsyncJob
New-Alias -Name raj -Value Receive-AsyncJob
New-Alias -Name rmaj -Value Remove-AsyncJob
New-Alias -Name spaj -Value Stop-AsyncJob
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

Export-ModuleMember -Alias * -Function 'Start-AsyncJob','Stop-AsyncJob','Remove-AsyncJob','Get-AsyncJob','Receive-AsyncJob'
