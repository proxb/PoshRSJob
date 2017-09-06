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
        $jobs = 1..15 | Start-RSJob @params
    }
    else {
        $jobs = 1..15 | Foreach-Object { $_ | Start-RSJob @params }
    }
    $jobs | Wait-RSJob | Receive-RSJob
    $jobs | Remove-RSJob
}

$ParameterTestCases = @(
    @{
       Case = 'by job object'
       Mode = 0
       Param = { @{ Job = $TestJob } }
    },
    @{
       Case = 'by job object positioned'
       Mode = 1
       Param = { $TestJob }
    },
    @{
       Case = 'by job object from pipeline (name)'
       Mode = 2
       Param = { '' | Select @{n='Job'; e={$TestJob}} }
    },
    @{
       Case = 'by job object from pipeline (value)'
       Mode = 2
       Param = { $TestJob }
    },

    @{
       Case = 'by id'
       Mode = 0
       Param = { @{ Id = ($TestJob | Select-Object -Expand id) } }
    },
    @{
       Case = 'by id positioned'
       Mode = 1
       Param = { $TestJob | Select-Object -Expand id }
    },
    @{
       Case = 'by id from pipeline (name)'
       Mode = 2
       Param = { $TestJob | Select-Object id }
    },
    @{
       Case = 'by id from pipeline (value)'
       Mode = 2
       Param = { $TestJob | Select-Object -Expand id }
    },

    @{
       Case = 'by name'
       Mode = 0
       Param = { @{ Name = ($TestJob | Select-Object -Expand Name) } }
    },
    @{
       Case = 'by name positioned'
       Mode = 1
       Param = { $TestJob | Select-Object -Expand Name }
    },
    @{
       Case = 'by name from pipeline (name)'
       Mode = 2
       Param = { $TestJob | Select-Object Name }
    },
    @{
       Case = 'by name from pipeline (value)'
       Mode = 2
       Param = { $TestJob | Select-Object -Expand Name }
    },

    @{
       Case = 'by InstanceID'
       Mode = 0
       Param = { @{ InstanceID = ($TestJob | Select-Object -Expand InstanceID) } }
    },
    @{
       Case = 'by InstanceID from pipeline (name)'
       Mode = 2
       Param = { $TestJob | Select-Object InstanceID }
    }
)

Describe "PoshRSJob PS$($PSVersion)" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should load all functions' {
            $Commands = @( Get-Command -CommandType Function -Module PoshRSJob | Select-Object -ExpandProperty Name)
            $Commands.count | Should be 6
            $Commands -contains "Get-RSJob"     | Should be $True
            $Commands -contains "Receive-RSJob" | Should be $True
            $Commands -contains "Remove-RSJob"  | Should be $True
            $Commands -contains "Start-RSJob"   | Should be $True
            $Commands -contains "Stop-RSJob"    | Should be $True
            $Commands -contains "Wait-RSJob"    | Should be $True
        }
        It 'should load all aliases' {
            $Commands = @( Get-Command -CommandType Alias -Module PoshRSJob | Select-Object -ExpandProperty Name)
            $Commands.count | Should be 6
            $Commands -contains "gsj"     | Should be $True
            $Commands -contains "rmsj" | Should be $True
            $Commands -contains "rsj"  | Should be $True
            $Commands -contains "ssj"   | Should be $True
            $Commands -contains "spsj"    | Should be $True
            $Commands -contains "wsj"    | Should be $True
        }
        It 'should initialize necessary variables' {
            $PSCmdlet.SessionState.PSVariable.Get('PoshRS_RunspacePools').Name | Should Be 'PoshRS_RunspacePools'
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
        InModuleScope PoshRSJob {
            It 'should get first param list, 4 variables' {
                $Output1 = @(GetParamVariable -ScriptBlock {
                    [CmdletBinding()]
                    #Comment
                    Param($a = $b + $c,
                    $d,
                    [Parameter()]
                    $e = [pscustomobject]@{
                        a = $c
                        b = invoke-command { $args } -argumentlist $b,$c,3
                    },
                    [ValidateScript({$_ -eq $c,$b})]
                    $f)
                    $a, $b, $c, $d, $e
                    Invoke-Command { param($ip) $ip }
                }) -join ''
                $Output1 | Should Be 'adef'
            }
            It 'should not get internal param list' {
                $Output1 = @(GetParamVariable -ScriptBlock {
                    $a, $b, $c, $d, $e
                    Invoke-Command { param($ip) $ip }
                }).Count
                $Output1 | Should Be 0
            }
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
        It 'should support VariablesToImport syntax' {
            $Output2 = @(
                $tester0 = 'tester012'; $testvar1 = 'testvar124'; $testvar2 = 'testvar248'
                Start-RSJob  @Verbose -ScriptBlock {
                    $tester0
                    $testvar1
                    $testvar2
                } -VariablesToImport tester0,testvar* | Wait-RSJob | Receive-RSJob)
            ($Output2 -join ',') | Should Be 'tester012,testvar124,testvar248'
        }
    }
}

Describe "Get-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should return all job details' {
            $Output = @( Get-RSJob @Verbose )
            $Props = $Output[0].PSObject.Properties | Select-Object -ExpandProperty Name

            $Output.count | Should be 11
            $Props -contains "Id" | Should be $True
            $Props -contains "State" | Should be $True
            $Props -contains "HasMoreData" | Should be $True
        }

        It 'should return job by state' {
            1..10 | Start-RSJob { Start-Sleep -Seconds 5; $_ } -Throttle 5
            $Jobs = @(Get-RSJob -State NotStarted)
            $Jobs.Count | Should Be 5
        }

        It 'should return job details <Case>' -TestCases $ParameterTestCases {
            param(
                $Case,
                $Mode,
                $Param
            )

            $TestJob = Start-RSJob -Name "TestJob $Case" -ScriptBlock { $text=$using:Case; "Working on $text" }

            switch ($Mode) {
                0 {
                    $Parameters = & $Param
                    $Output = @( Get-RSJob @Verbose @Parameters )
                }
                1 {
                    $Parameters = & $Param
                    $Output = @( Get-RSJob @Verbose $Parameters )
                }
                2 {
                    $Parameters = & $Param
                    $Output = @( $Parameters | Get-RSJob @Verbose )
                }
                default {
                    # Fail test on invalid mode
                    'Invalid mode !' | Should be 'Invalid mode !!!'
                }
            }

            $Output.Count | Should be 1
			$Output[0] -is 'RSJob' | Should be $true
			$Output[0].Name | Should be "TestJob $Case"
        }
    }
}

Describe "Stop-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should not stop a job' {
            Stop-RSJob | Should BeNullOrEmpty
        }
        It 'should stop a job' {
            $Job = 1 | Start-RSJob -ScriptBlock {
                While ($True) {$Null}
            }
            $Job | Stop-RSJob
            Start-Sleep -Milliseconds 100
            $Job.State | Should be 'Stopped'
        }
        It 'should stop a job <Case>' -TestCases $ParameterTestCases {
            param(
                $Case,
                $Mode,
                $Param
            )
            $TestJob = 1 | Start-RSJob -ScriptBlock {
                While ($True) {$Null}
            }
            switch ($Mode) {
                0 {
                    $Parameters = & $Param
                    Stop-RSJob @Parameters
                }
                1 {
                    $Parameters = & $Param
                    Stop-RSJob $Parameters
                }
                2 {
                    $Parameters = & $Param
                    $Parameters | Stop-RSJob
                }
                default {
                    # Fail test on invalid mode
                    'Invalid mode !' | Should be 'Invalid mode !!!'
                }
            }
            Start-Sleep -Milliseconds 100
            $TestJob.State | Should be 'Stopped'
        }
    }
}

Describe "Wait-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest

        It 'should not wait a job' {
            Wait-RSJob | Should BeNullOrEmpty
        }

        It 'should wait for jobs <Case>' -TestCases $ParameterTestCases {
            param(
                $Case,
                $Mode,
                $Param
            )
            $StartDate = Get-Date
            $TestJob = 0 | Start-RSJob @Verbose -ScriptBlock {
                Start-Sleep -seconds 3
                Get-Date
            }
            switch ($Mode) {
                0 {
                    $Parameters = & $Param
                    Wait-RSJob @Parameters # Omitted verbose to avoid clutter
                }
                1 {
                    $Parameters = & $Param
                    Wait-RSJob $Parameters # Omitted verbose to avoid clutter
                }
                2 {
                    $Parameters = & $Param
                    $Parameters | Wait-RSJob # Omitted verbose to avoid clutter
                }
                default {
                    # Fail test on invalid mode
                    'Invalid mode !' | Should be 'Invalid mode !!!'
                }
            }
            $EndDate = Get-Date
            ( $EndDate - $StartDate ).TotalSeconds -gt 3 | Should be $True
        }
    }
}

Describe "Receive-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest

        It 'should not retrieve a job' {
            Receive-RSJob | Should BeNullOrEmpty
        }

        It 'should retrieve job data <Case>' -TestCases $ParameterTestCases {
            param(
                $Case,
                $Mode,
                $Param
            )
            $TestJob = Get-RSJob -Name "TestJob $Case"

            switch ($Mode) {
                0 {
                    $Parameters = & $Param
                    $Output = @( Receive-RSJob @Verbose @Parameters )
                }
                1 {
                    $Parameters = & $Param
                    $Output = @( Receive-RSJob @Verbose $Parameters )
                }
                2 {
                    $Parameters = & $Param
                    $Output = @( $Parameters | Receive-RSJob @Verbose)
                }
                default {
                    # Fail test on invalid mode
                    'Invalid mode !' | Should be 'Invalid mode !!!'
                }
            }
            $Output.Count | Should be 1
            $Output[0] | Should be "Working on $Case"
        }
    }
}

Describe "Remove-RSJob PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest

        It 'should not remove a job' {
            Remove-RSJob | Should BeNullOrEmpty
        }

        It 'should only remove specified jobs <Case>' -TestCases $ParameterTestCases {
            param(
                $Case,
                $Mode,
                $Param
            )
            $TestJobs = @(Get-RSJob | Where-Object { $_.Name -match "^TestJob " })
            $TestJobs.Count -gt 0 | Should Be $True

            $TestJob = $TestJobs | Where-Object { $_.Name -eq "TestJob $Case" }
			$TestJob -is 'RSJob' | Should be $true

            $AllIDs = @( $TestJobs | Select-Object -ExpandProperty Id )

            switch ($Mode) {
                0 {
                    $Parameters = & $Param
                    Remove-RSJob @Verbose @Parameters
                }
                1 {
                    $Parameters = & $Param
                    Remove-RSJob @Verbose $Parameters
                }
                2 {
                    $Parameters = & $Param
                    $Parameters | Remove-RSJob @Verbose
                }
                default {
                    # Fail test on invalid mode
                    'Invalid mode !' | Should be 'Invalid mode !!!'
                }
            }

            $RemainingIDs = @( Get-RSJob @Verbose -Id $AllIDs | Select-Object -ExpandProperty Id )
            #We only removed one
            $RemainingIDs.Count -eq ($AllIDs.Count - 1) | Should Be $True
            #We removed the right ID
            $RemainingIDs -notcontains $TestJob.Id | Should Be $True
        }

        It 'should not remove job' {
            $TestJob = 1 | Start-RSJob -Name 'ByForce' -ScriptBlock {
                While ($True) {$Null}
            }
			$TestJob -is 'RSJob' | Should be $true
            { Remove-RSJob $TestJob -ErrorAction Stop } | Should Throw
        }
        It 'should remove job by force' {
            $TestJob = Get-RSJob -Name 'ByForce'
			$TestJob -is 'RSJob' | Should be $true
            { Remove-RSJob $TestJob -Force } | Should Not Throw
            $TestJob = Get-RSJob -Name 'ByForce'
			$TestJob | Should BeNullOrEmpty
        }
        It 'should remove all jobs' {
            Get-RSJob @Verbose | Remove-RSJob @Verbose
            $Output = @( Get-RSJob @Verbose )

            $Output.Count | Should be 0
        }
    }
}

Describe "Test RSJob Throttling" {
    It "Full Pipe input" {
        $StartDate = Get-Date
        Test-RSJob $true
            $EndDate = Get-Date
        ( $EndDate - $StartDate ).TotalSeconds -gt 15 | Should be $True
    }
    It "OneByOne Pipe input" {
        $StartDate = Get-Date
        Test-RSJob $false
            $EndDate = Get-Date
            ( $EndDate - $StartDate ).TotalSeconds -gt 15 | Should be $True
    }
}

Describe "Module OnRemove Actions PS$PSVersion" {
    Context 'Strict mode' {
        Get-RSJob | Remove-RSJob
        Remove-Module -Name PoshRSJob -ErrorAction SilentlyContinue
        It 'should remove all variables' {
            {Get-Variable PoshRS_Jobs -ErrorAction Stop} | Should Throw
            {Get-Variable PoshRS_JobCleanup -ErrorAction Stop} | Should Throw
            {Get-Variable PoshRS_JobID -ErrorAction Stop} | Should Throw
            {Get-Variable PoshRS_RunspacePoolCleanup -ErrorAction Stop} | Should Throw
            {Get-Variable PoshRS_RunspacePools -ErrorAction Stop} | Should Throw
        }
    }
}
