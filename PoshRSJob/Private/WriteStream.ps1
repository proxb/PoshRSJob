Function WriteStream {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [Object]$IndividualJob
    )
    Begin {
        $Streams = "Verbose","Warning","Error","Output"
    }

    Process {
        ForEach ($Stream in $Streams)
        {
            If (($IndividualJob.$Stream.Count -gt 0) -AND (-NOT ($Null -eq $IndividualJob.$Stream)))
            {
                Switch ($Stream) {
                    "Verbose" { $IndividualJob | Select -ExpandProperty Verbose | ForEach { Write-Verbose $_ } }
                    "Warning" { $IndividualJob | Select -ExpandProperty Warning | ForEach { Write-Warning $_ } }
                    "Error"   { $IndividualJob.Error.Exception | Select -ExpandProperty Message | ForEach { Write-Error $_ } }
                    "Output"  { $IndividualJob | Select -ExpandProperty Output }
                }
            }

        }
    }
}