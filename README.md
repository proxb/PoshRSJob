PoshRSJob (1.5.5.0)
===================

[![Build status](https://ci.appveyor.com/api/projects/status/svrd4ho4otugki24?svg=true)](https://ci.appveyor.com/project/proxb/poshrsjob)

Provides an alternative to PSjobs with greater performance and less overhead to run commands in the background, freeing up the console.

####Download and install PoshRSJob using PowerShell PSGet:
```PowerShell
Install-Module -Name PoshRSJob
```

More information and examples here: http://learn-powershell.net/2015/04/19/latest-updates-to-poshrsjob/

Older post with some legacy examples found here: http://learn-powershell.net/2015/03/31/introducing-poshrsjob-as-an-alternative-to-powershell-jobs/

####Examples
=================
```PowerShell
$Test = 'test'
$Something = 1..10
1..5|start-rsjob -Name {$_} -ScriptBlock {
        [pscustomobject]@{
            Result=($_*2)
            Test=$Using:Test
            Something=$Using:Something
        }
}            
```
        Id  Name                 State           HasMoreData  HasErrors    Command
        --  ----                 -----           -----------  ---------    -------
        76  1                    Completed       True         False        ...
        77  2                    Running         False        False        ...
        78  3                    Running         False        False        ...
        79  4                    Completed       False        False        ...
        80  5                    Completed       False        False        ...

```PowerShell
Get-RSjob | Receive-RSJob
```

        Result Test Something
        ------ ---- ---------
         2 test {1, 2, 3, 4...}
         4 test {1, 2, 3, 4...}
         6 test {1, 2, 3, 4...}
         8 test {1, 2, 3, 4...}
        10 test {1, 2, 3, 4...}
        
        Description
        -----------
        Shows an example of the $Using: variable being used in the scriptblock.

####This shows the streaming aspect with Wait-RSJob
```PowerShell
1..10|Start-RSJob {
    if (1 -BAND $_){
        "First ($_)"
    }Else{
        Start-sleep -seconds 2
        "Last ($_)"
    }
}|Wait-RSJob|Receive-RSJob|ForEach{"I am $($_)"}
```
![alt tag](https://github.com/proxb/PoshRSJob/blob/master/Images/RSJobStreamingExample.gif)
