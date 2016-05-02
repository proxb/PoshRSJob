$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module 
$PSModuleRoot = $PSModule.ModuleBase

#region RSJob Collections
Write-Verbose "Creating RS collections"
New-Variable PoshRS_Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Global
New-Variable PoshRS_jobCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Global
New-Variable PoshRS_JobID -Value ([int64]0) -Option ReadOnly -Scope Global
New-Variable PoshRS_RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Global
New-Variable PoshRS_RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Global
#endregion RSJob Collections

#region Cleanup Routine
Write-Verbose "Creating routine to monitor RS jobs"
$PoshRS_jobCleanup.Flag=$True
$PoshRS_jobCleanup.Host = $Host
$PoshRS_jobCleanup.Runspace =[runspacefactory]::CreateRunspace()   
$PoshRS_jobCleanup.Runspace.Open()         
$PoshRS_jobCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_jobCleanup",$PoshRS_jobCleanup)     
$PoshRS_jobCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_Jobs",$PoshRS_Jobs) 
$PoshRS_jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("Begin Do Loop") 
    Do {   
        [System.Threading.Monitor]::Enter($PoshRS_Jobs.syncroot) 
        Foreach($job in $PoshRS_Jobs) {
            $job.state = $job.InnerJob.InvocationStateInfo.State
            If ($job.Handle.isCompleted -AND (-NOT $Job.Completed)) {   
                #$PoshRS_jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) completed")  
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
                $job.Completed = $True  
                #Return type from Invoke() is a generic collection; need to verify the first index is not NULL
                If (($Data.Count -gt 0) -AND (-NOT ($Null -eq $Data[0]))) {   
                    $job.output = $Data
                    $job.HasMoreData = $True                            
                }              
                $Error.Clear()
            } 
        }        
        [System.Threading.Monitor]::Exit($PoshRS_Jobs.syncroot)
        Start-Sleep -Milliseconds 100     
    } while ($PoshRS_jobCleanup.Flag)
})
$PoshRS_jobCleanup.PowerShell.Runspace = $PoshRS_jobCleanup.Runspace
$PoshRS_jobCleanup.Handle = $PoshRS_jobCleanup.PowerShell.BeginInvoke()  

Write-Verbose "Creating routine to monitor Runspace Pools"
$PoshRS_RunspacePoolCleanup.Flag=$True
$PoshRS_RunspacePoolCleanup.Host=$Host
#5 minute timeout for unused runspace pools
$PoshRS_RunspacePoolCleanup.Timeout = [timespan]::FromMinutes(1).Ticks
$PoshRS_RunspacePoolCleanup.Runspace =[runspacefactory]::CreateRunspace()
 
#Create Type Collection so the object will work properly 
$Types = Get-ChildItem "$($PSScriptRoot)\TypeData" -Filter *Types* | Select -ExpandProperty Fullname 
$Types | ForEach { 
    $TypeEntry = New-Object System.Management.Automation.Runspaces.TypeConfigurationEntry -ArgumentList $_ 
    $PoshRS_RunspacePoolCleanup.Runspace.RunspaceConfiguration.types.Append($TypeEntry) 
} 
  
$PoshRS_RunspacePoolCleanup.Runspace.Open()         
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_RunspacePoolCleanup",$PoshRS_RunspacePoolCleanup)     
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("PoshRS_RunspacePools",$PoshRS_RunspacePools) 
$PoshRS_RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("ParentHost",$Host) 
$PoshRS_RunspacePoolCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do { 
        $DisposePoshRS_RunspacePools=$False  
        If ($PoshRS_RunspacePools.Count -gt 0) { 
            #$ParentHost.ui.WriteVerboseLine("$($PoshRS_RunspacePools | Out-String)")           
            [System.Threading.Monitor]::Enter($PoshRS_RunspacePools.syncroot) 
            Foreach($RunspacePool in $PoshRS_RunspacePools) {                
                #$ParentHost.ui.WriteVerboseLine("RunspacePool <$($RunspacePool.RunspaceID)> | MaxJobs: $($RunspacePool.MaxJobs) | AvailJobs: $($RunspacePool.AvailableJobs)")
                If (($RunspacePool.AvailableJobs -eq $RunspacePool.MaxJobs) -AND $PoshRS_RunspacePools.LastActivity.Ticks -ne 0) {
                    If ((Get-Date).Ticks - $RunspacePool.LastActivity.Ticks -gt $PoshRS_RunspacePoolCleanup.Timeout) {
                        #Dispose of runspace pool
                        $RunspacePool.RunspacePool.Close()
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
                $TempCollection | Where {
                    $_.CanDispose
                } | ForEach {
                    #$ParentHost.ui.WriteVerboseLine("Removing runspacepool <$($_.RunspaceID)>")
                    [void]$PoshRS_RunspacePools.Remove($_)
                }
            }
            Remove-Variable TempCollection
            [System.Threading.Monitor]::Exit($PoshRS_RunspacePools.syncroot)
        }
        Start-Sleep -Milliseconds 5000     
    } while ($PoshRS_RunspacePoolCleanup.Flag)
})
$PoshRS_RunspacePoolCleanup.PowerShell.Runspace = $PoshRS_RunspacePoolCleanup.Runspace
$PoshRS_RunspacePoolCleanup.Handle = $PoshRS_RunspacePoolCleanup.PowerShell.BeginInvoke() 
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
New-Alias -Name ssj -Value Start-RSJob -Force
New-Alias -Name gsj -Value Get-RSJob -Force
New-Alias -Name rsj -Value Receive-RSJob -Force
New-Alias -Name rmsj -Value Remove-RSJob -Force
New-Alias -Name spsj -Value Stop-RSJob -Force
New-Alias -Name wsj -Value Wait-RSJob -Force
#endregion Aliases

#region Handle Module Removal
$ExecutionContext.SessionState.Module.OnRemove ={
    $PoshRS_jobCleanup.Flag=$False
    $PoshRS_RunspacePoolCleanup.Flag=$False
    #Let sit for a second to make sure it has had time to stop
    Start-Sleep -Seconds 1
    $PoshRS_jobCleanup.PowerShell.EndInvoke($PoshRS_jobCleanup.Handle)
    $PoshRS_jobCleanup.PowerShell.Dispose()    
    $PoshRS_RunspacePoolCleanup.PowerShell.EndInvoke($PoshRS_RunspacePoolCleanup.Handle)
    $PoshRS_RunspacePoolCleanup.PowerShell.Dispose()
    Remove-Variable PoshRS_JobId -Scope Script -Force
    Remove-Variable PoshRS_Jobs -Scope Script -Force
    Remove-Variable PoshRS_jobCleanup -Scope Script -Force
    Remove-Variable PoshRS_RunspacePoolCleanup -Scope Script -Force
    Remove-Variable PoshRS_RunspacePools -Scope Script -Force
}
#endregion Handle Module Removal

#region Export Module Members
$ExportModule = @{
    Alias = @('gsj','rmsj','rsj','spsj','ssj','wsj')
    Function = @('Get-RSJob','Receive-RSJob','Remove-RSJob','Start-RSJob','Stop-RSJob','Wait-RSJob')
    Variable = @('PoshRS_JobId','PoshRS_Jobs','PoshRS_jobCleanup','PoshRS_RunspacePoolCleanup','PoshRS_RunspacePools')
}
Export-ModuleMember @ExportModule
#endregion Export Module Members