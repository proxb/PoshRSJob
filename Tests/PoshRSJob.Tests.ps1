#handle PS2
if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

#Verbose output if this isn't master, or we are testing locally
$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master" -or -not $env:APPVEYOR_REPO_BRANCH)
{
    $Verbose.add("Verbose",$False)
}


Import-Module $PSScriptRoot\..\PoshRSJob\PoshRSJob -Verbose -Force -ErrorAction SilentlyContinue

<#
$PSVersion = $PSVersionTable.PSVersion.Major
Switch ($PSVersion) {
    4 {Import-Module $PSScriptRoot\..\PoshRSJob\PoshRSJob -Force -ErrorAction SilentlyContinue}
    2 {Import-Module PoshRSJob -Force -ErrorAction SilentlyContinue}
}
#>

function Test-RSJob([bool]$FullPiping=$true) {
    $ScriptBlock = { "{0}: {1}" -f $_, [DateTime]::Now; Start-Sleep -Seconds 5 }
    $params = @{ Batch='throttletest'; ScriptBlock=$ScriptBlock; Throttle=5 }
    if ($FullPiping) {
        $jobs = 1..25 | Start-RSJob @params
    }
    else {
        $jobs = 1..25 | Foreach-Object { $_ | Start-RSJob @params }
    }
    $jobs | Wait-RSJob | Receive-RSJob
    $jobs | Remove-RSJob
}

Describe "PoshRSJob PS$($PSVersion)" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should load all functions' {
            $Commands = @( Get-Command -CommandType Function -Module PoshRSJob | Select -ExpandProperty Name)
            $Commands.count | Should be 6
            $Commands -contains "Get-RSJob"     | Should be $True
            $Commands -contains "Receive-RSJob" | Should be $True
            $Commands -contains "Remove-RSJob"  | Should be $True
            $Commands -contains "Start-RSJob"   | Should be $True
            $Commands -contains "Stop-RSJob"    | Should be $True
            $Commands -contains "Wait-RSJob"    | Should be $True
        }
        It 'should load all aliases' {
            $Commands = @( Get-Command -CommandType Alias -Module PoshRSJob | Select -ExpandProperty Name)
            $Commands.count | Should be 6
            $Commands -contains "gsj"     | Should be $True
            $Commands -contains "rmsj" | Should be $True
            $Commands -contains "rsj"  | Should be $True
            $Commands -contains "ssj"   | Should be $True
            $Commands -contains "spsj"    | Should be $True
            $Commands -contains "wsj"    | Should be $True
        }
        It 'should initialize necessary variables' {
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_runspacepools').Name | Should Be 'PoshRS_RunspacePools'
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_RunspacePoolCleanup').Name | Should Be 'PoshRS_RunspacePoolCleanup'
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_JobCleanup').Name | Should Be 'PoshRS_JobCleanup'
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_JobID').Name | Should Be 'PoshRS_JobID'
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_Jobs').Name | Should Be 'PoshRS_Jobs'
        }
    }
}
 
Describe "Start-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'each job should increment Id by 1' {
            $FirstJob = Start-RSJob {$Null}
            $InitialID = $FirstJob.Id
            $SecondJob = Start-RSJob {$Null}
            $NextID = $SecondJob.Id
            $NextID - $InitialID | Should Be 1
 
        }
        It 'should return initial job details' {           
            $Output1 = @( 1 | Start-RSJob @Verbose -ScriptBlock {
                Param($Object)
                $Object
            } )
            $Output5 = @( 1..5 | Start-RSJob @Verbose -ScriptBlock {
                Param($Object)
                $Object
            } )
            $Output1.Count | Should be 1
            $Output5.Count | Should be 5
        }        
        It 'should support $using syntax' {
            $Test = "5"
            $Output1 = 1 | Start-RSJob @Verbose -ScriptBlock {
                $Using:Test
            } | Wait-RSJob | Receive-RSJob
            $Output1 | Should Be 5
        }
        It 'should support pipeline $_ syntax' {
            $Output1 = @( 1 | Start-RSJob @Verbose -ScriptBlock {
                $_
            } ) | Wait-RSJob | Receive-RSJob
            $Output1 | Should Be 1
        }             
    }
}

Describe "Stop-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should stop a job' {
            $Job = 1 | Start-RSJob -ScriptBlock {
                While ($True) {$Null}
            }
            $Job | Stop-RSJob
            Start-Sleep -Milliseconds 100
            $Job.State | Should be 'Stopped'
        }
    }
}
 
Describe "Get-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should return all job details' {
            $Output = @( Get-RSJob @Verbose )
            $Props = $Output[0].PSObject.Properties | Select -ExpandProperty Name
           
            $Output.count | Should be 11
            $Props -contains "Id" | Should be $True
            $Props -contains "State" | Should be $True
            $Props -contains "HasMoreData" | Should be $True
        }       
        It 'should return job details based on ID' {
            $Output = @( Get-RSJob @Verbose -Id 1 )
            $Props = $Output[0].PSObject.Properties | Select -ExpandProperty Name
           
            $Output.count | Should be 1
            $Props -contains "Id" | Should be $True
            $Props -contains "State" | Should be $True
            $Props -contains "HasMoreData" | Should be $True
        }
        It 'should return job details based on Name' {
            $Output = @( Get-RSJob @Verbose -Name Job2 )
            $Props = $Output[0].PSObject.Properties | Select -ExpandProperty Name
           
            $Output.count | Should be 1
            $Props -contains "Id" | Should be $True
            $Props -contains "State" | Should be $True
            $Props -contains "HasMoreData" | Should be $True
        }
    }
}
 
Describe "Remove-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should remove jobs' {
            Get-RSJob @Verbose | Remove-RSJob @Verbose
            $Output = @( Get-RSJob @Verbose )
           
            $Output.count | Should be 0
        }
        It 'should only remove specified jobs by ID' {
             $TestJobs = @( 1..5 | Start-RSJob @Verbose -ScriptBlock { "" } )
             Start-Sleep -Seconds 2
             $ThisJobId = $TestJobs[0].ID
             $AllIDs = @( $TestJobs | Select -ExpandProperty Id )
             Remove-RSJob @Verbose -Id $ThisJobId
             $RemainingIDs = @( Get-RSJob @Verbose -Id $AllIDs | Select -ExpandProperty Id )
             #We only removed one
             $RemainingIDs.count -eq ($AllIDs.count - 1) | Should Be $True
             #We removed the right ID
             $RemainingIDs -notcontains $ThisJobId | Should Be $True
        }
        It 'should only remove specified jobs by Name' {
             $TestJobs = @( 1..5 | Start-RSJob @Verbose -ScriptBlock { "" } )
             Start-Sleep -Seconds 2
             $ThisJobName = $TestJobs[0].Name
             $AllNames = @( $TestJobs | Select -ExpandProperty Name )
             Remove-RSJob @Verbose -Name $ThisJobName
             $RemainingNames = @( Get-RSJob @Verbose -Name $AllNames | Select -ExpandProperty Name )
             #We only removed one
             $RemainingNames.count -eq ($AllNames.count - 1) | Should Be $True
             #We removed the right ID
             $RemainingNames -notcontains $ThisJobName | Should Be $True           
        }
        It 'should only remove specified jobs by InputObject' {            
             $TestJobs = @( 1..5 | Start-RSJob @Verbose -ScriptBlock { "" })
             Start-Sleep -Seconds 2
             $ThisJob = $TestJobs[0]
             $ThisJob | Remove-RSJob @Verbose
             $RemainingNames = @( $TestJobs | Get-RSJob @Verbose | Select -ExpandProperty Name)
             #We only removed one
             $RemainingNames.count -eq ($TestJobs.count - 1) | Should Be $True
             #We removed the right ID
             $RemainingNames -notcontains $ThisJob.Name | Should Be $True             
        }
    }
}
 
Describe "Receive-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should retrieve job data' {
            $TestJob = 0 | Start-RSJob @Verbose -ScriptBlock {"Working on $_"}
            Start-Sleep -Seconds 1
           
            $Output = @( $TestJob | Receive-RSJob @Verbose )
            $Output.Count | Should be 1
            $Output[0] | Should be "Working on 0"
           
        }
        It 'should not remove the job' {
            $TestJob = 0 | Start-RSJob @Verbose -ScriptBlock {""}
            Start-Sleep -Seconds 1
            $TestJob | Receive-RSJob @Verbose | Out-Null
           
            $Output = @( $TestJob | Get-RSJob @Verbose )
            $Output.Count | Should be 1
        }
    }
}
 
Describe "Wait-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should wait for jobs' {
            $StartDate = Get-Date
            $TestJob = 0 | Start-RSJob @Verbose -ScriptBlock {
                Start-Sleep -seconds 5
                Get-Date
            }
            $TestJob | Wait-RSJob # Omitted verbose to avoid clutter
            $EndDate = Get-Date           
            ( $EndDate - $StartDate ).TotalSeconds -gt 5 | Should be $True
        }
    }
}

<#
Describe "Test RSJob Throttling" {
	It "Full Pipe input" {
		$StartDate = Get-Date
		Test-RSJob $true
        	$EndDate = Get-Date           
		( $EndDate - $StartDate ).TotalSeconds -gt 25 | Should be $True
	}
	It "OneByOne Pipe input" {
		$StartDate = Get-Date
		Test-RSJob $false
        	$EndDate = Get-Date           
        	( $EndDate - $StartDate ).TotalSeconds -gt 25 | Should be $True
	}
}
#>

Describe "Module OnRemove Actions PS$PSVersion" {
    Context 'Strict mode' {
        Get-RSJob | Remove-RSJob
        Remove-Module -Name PoshRSJob -ErrorAction SilentlyContinue
        It 'should remove all variables' {
            {Get-Variable Jobs -ErrorAction Stop} | Should Throw
            {Get-Variable JobCleanup -ErrorAction Stop} | Should Throw
            {Get-Variable JobID -ErrorAction Stop} | Should Throw
            {Get-Variable RunspacePoolCleanup -ErrorAction Stop} | Should Throw
            {Get-Variable RunspacePools -ErrorAction Stop} | Should Throw
        }
    }
}
