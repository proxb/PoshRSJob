$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module 
$PSModuleRoot = $PSModule.ModuleBase
#region Custom Object
If ($PSVersionTable.PSVersion.Major -gt 2) {
    Write-Verbose "Creating custom RSJob object through reflection"
    #region Module Builder
    $Domain = [AppDomain]::CurrentDomain
    $DynAssembly = New-Object System.Reflection.AssemblyName('etc')
    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('etc', $False)
    #endregion Module Builder
 
    #region V3+ Class Creation
 
    #region V2UsingVariable
    #region Build Class
    $TypeBuilder = $ModuleBuilder.DefineType('PoshRS.PowerShell.V2UsingVariable', 'Public, Class')
    #endregion Build Class
 
    #region Properties
    [void]$TypeBuilder.DefineField('Name',[string],'Public')
    [void]$TypeBuilder.DefineProperty('Name','HasDefault',[string],$Null)
    [void]$TypeBuilder.DefineField('NewName',[string],'Public')
    [void]$TypeBuilder.DefineProperty('NewName','HasDefault',[string],$Null)
    [void]$TypeBuilder.DefineField('Value',[object],'Public')
    [void]$TypeBuilder.DefineProperty('Value','HasDefault',[string],$Null)
    [void]$TypeBuilder.DefineField('NewVarName',[string],'Public')
    [void]$TypeBuilder.DefineProperty('NewVarName','HasDefault',[string],$Null)
    #endregion Properties
 
    #Create the type
    [void]$TypeBuilder.CreateType()
    #endregion V2UsingVariable
 
    #region RSRunspacePool
    #region Build Class
    $TypeBuilder = $ModuleBuilder.DefineType('PoshRS.PowerShell.RSRunspacePool', 'Public, Class')
    #endregion Build Class
 
    #region Properties
    [void]$TypeBuilder.DefineField('RunspacePool',[System.Management.Automation.Runspaces.RunspacePool],'Public')
    [void]$TypeBuilder.DefineProperty('RunspacePool','HasDefault',[System.Management.Automation.Runspaces.RunspacePool],$Null)
    [void]$TypeBuilder.DefineField('State',[System.Management.Automation.Runspaces.RunspacePoolState],'Public')
    [void]$TypeBuilder.DefineProperty('State','HasDefault',[System.Management.Automation.Runspaces.RunspacePoolState],$Null)
    [void]$TypeBuilder.DefineField('AvailableJobs',[int],'Public')
    [void]$TypeBuilder.DefineProperty('AvailableJobs','HasDefault',[int],$Null)
    [void]$TypeBuilder.DefineField('MaxJobs',[int],'Public')
    [void]$TypeBuilder.DefineProperty('MaxJobs','HasDefault',[int],$Null)
    [void]$TypeBuilder.DefineField('LastActivity',[DateTime],'Public')
    [void]$TypeBuilder.DefineProperty('LastActivity','HasDefault',[DateTime],$Null)
    [void]$TypeBuilder.DefineField('RunspacePoolID',[System.Guid],'Public')
    [void]$TypeBuilder.DefineProperty('RunspacePoolID','HasDefault',[System.Guid],$Null)
    [void]$TypeBuilder.DefineField('CanDispose',[bool],'Public')
    [void]$TypeBuilder.DefineProperty('CanDispose','HasDefault',[bool],$Null)
    #endregion Properties
 
    #Create the type
    [void]$TypeBuilder.CreateType()
    #endregion RSRunspacePool
 
    #region RSJob
    #region Build Class
    $TypeBuilder = $ModuleBuilder.DefineType('PoshRS.PowerShell.RSJob', 'Public, Class')
    #endregion Build Class
 
    #region Properties
    [void]$TypeBuilder.DefineField('Name',[string],'Public')
    [void]$TypeBuilder.DefineProperty('Name','HasDefault',[string],$Null)
    [void]$TypeBuilder.DefineField('ID',[int],'Public')
    [void]$TypeBuilder.DefineProperty('ID','HasDefault',[int],$Null)
    [void]$TypeBuilder.DefineField('State',[System.Management.Automation.PSInvocationState],'Public')
    [void]$TypeBuilder.DefineProperty('State','HasDefault',[System.Management.Automation.PSInvocationState],$Null)
    [void]$TypeBuilder.DefineField('InstanceID',[System.Guid],'Public')
    [void]$TypeBuilder.DefineProperty('InstanceID','HasDefault',[System.Guid],$Null)
    [void]$TypeBuilder.DefineField('Handle',[object],'Public')
    [void]$TypeBuilder.DefineProperty('Handle','HasDefault',[object],$Null)
    [void]$TypeBuilder.DefineField('Runspace',[object],'Public')
    [void]$TypeBuilder.DefineProperty('Runspace','HasDefault',[object],$Null)
    [void]$TypeBuilder.DefineField('InnerJob',[System.Management.Automation.PowerShell],'Public')
    [void]$TypeBuilder.DefineProperty('InnerJob','HasDefault',[System.Management.Automation.PowerShell],$Null)
    [void]$TypeBuilder.DefineField('Finished',[System.Threading.ManualResetEvent],'Public')
    [void]$TypeBuilder.DefineProperty('Finished','HasDefault',[System.Threading.ManualResetEvent],$Null)
    [void]$TypeBuilder.DefineField('Command',[string],'Public')
    [void]$TypeBuilder.DefineProperty('Command','HasDefault',[string],$Null)
    [void]$TypeBuilder.DefineField('Error',[System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]],'Public')
    [void]$TypeBuilder.DefineProperty('Error','HasDefault',[System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]],$Null)
    [void]$TypeBuilder.DefineField('Verbose',[System.Management.Automation.PSDataCollection[System.Management.Automation.VerboseRecord]],'Public')
    [void]$TypeBuilder.DefineProperty('Verbose','HasDefault',[System.Management.Automation.PSDataCollection[System.Management.Automation.VerboseRecord]],$Null)
    [void]$TypeBuilder.DefineField('Debug',[System.Management.Automation.PSDataCollection[System.Management.Automation.DebugRecord]],'Public')
    [void]$TypeBuilder.DefineProperty('Debug','HasDefault',[System.Management.Automation.PSDataCollection[System.Management.Automation.DebugRecord]],$Null)
    [void]$TypeBuilder.DefineField('Warning',[System.Management.Automation.PSDataCollection[System.Management.Automation.WarningRecord]],'Public')
    [void]$TypeBuilder.DefineProperty('Warning','HasDefault',[System.Management.Automation.PSDataCollection[System.Management.Automation.WarningRecord]],$Null)
    [void]$TypeBuilder.DefineField('Progress',[System.Management.Automation.PSDataCollection[System.Management.Automation.ProgressRecord]],'Public')
    [void]$TypeBuilder.DefineProperty('Progress','HasDefault',[System.Management.Automation.PSDataCollection[System.Management.Automation.ProgressRecord]],$Null)
    [void]$TypeBuilder.DefineField('HasMoreData',[bool],'Public')
    [void]$TypeBuilder.DefineProperty('HasMoreData','HasDefault',[bool],$Null)
    [void]$TypeBuilder.DefineField('HasErrors',[bool],'Public')
    [void]$TypeBuilder.DefineProperty('HasErrors','HasDefault',[bool],$Null)
    [void]$TypeBuilder.DefineField('Output',[Object],'Public')
    [void]$TypeBuilder.DefineProperty('Output','HasDefault',[Object],$Null)
    [void]$TypeBuilder.DefineField('RunspacePoolID',[System.Guid],'Public')
    [void]$TypeBuilder.DefineProperty('RunspacePoolID','HasDefault',[System.Guid],$Null)
    [void]$TypeBuilder.DefineField('Completed',[bool],'Public')
    [void]$TypeBuilder.DefineProperty('Completed','HasDefault',[bool],$Null)
    [void]$TypeBuilder.DefineField('Batch',[string],'Public')
    [void]$TypeBuilder.DefineProperty('Batch','HasDefault',[string],$Null)
    #endregion Properties
 
    #Create the type
    [void]$TypeBuilder.CreateType()
    #endregion RSJob
 
    #endregion V3+ Class Creation
}
Else {
#region V2 Class creation
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
}
#endregion V2 Class creation
#endregion Custom Object

#region RSJob Collections
Write-Verbose "Creating RS collections"
New-Variable PoshRS_Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Script
New-Variable PoshRS_jobCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Script
New-Variable PoshRS_JobID -Value ([int64]0) -Option ReadOnly -Scope Script
New-Variable PoshRS_RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Script
New-Variable PoshRS_RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option ReadOnly -Scope Script
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
New-Alias -Name ssj -Value Start-RSJob
New-Alias -Name gsj -Value Get-RSJob
New-Alias -Name rsj -Value Receive-RSJob
New-Alias -Name rmsj -Value Remove-RSJob
New-Alias -Name spsj -Value Stop-RSJob
New-Alias -Name wsj -Value Wait-RSJob
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