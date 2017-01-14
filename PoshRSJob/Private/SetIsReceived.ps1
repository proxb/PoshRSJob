Function SetIsRecieved {
    Param (
        [parameter(ValueFromPipeline=$True)]
        [rsjob]$RSJob,
        [switch]$SetTrue
    )
    Begin{
        $Flags = 'nonpublic','instance','static'
    }    
    Process {
        If ($PSVersionTable.PSEdition -eq 'Core') {
            $RSJob.IsReceived = $SetTrue
        }
        Else {
            $Field = $RSJob.gettype().GetField('IsReceived',$Flags)
            $Field.SetValue($RSJob,$SetTrue)
        }
    }
}