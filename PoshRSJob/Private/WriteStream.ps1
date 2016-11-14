Function WriteStream {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [Object]$IndividualJob
    )
    Begin {
        $Streams = "Verbose","Warning","Error","Output","Debug"
    }

    Process {
        ForEach ($Stream in $Streams)
        {
            If (($IndividualJob.$Stream.Count -gt 0) -AND (-NOT ($Null -eq $IndividualJob.$Stream)))
            {
                Switch ($Stream) {
                    "Verbose" { $IndividualJob | Select -ExpandProperty Verbose| Where { $_.Message } | ForEach { $host.ui.WriteVerboseLine($_)} }                    
                    "Debug" { $IndividualJob | Select -ExpandProperty Debug| Where { $_.Message } | ForEach { $host.ui.WriteDebugLine($_)} }
                    "Warning" { $IndividualJob | Select -ExpandProperty Warning| Where { $_.Message } | ForEach { $host.ui.WriteWarningLine($_) } }
                    "Error"   { $IndividualJob.Error.Exception | Select -ExpandProperty Message | ForEach {$host.ui.WriteErrorLine($_)} }
                    "Output"  { $IndividualJob | Select -ExpandProperty Output }
                }
            }

        }
    }
}