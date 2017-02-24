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
            If (($IndividualJob.$Stream))
            {
                Switch ($Stream) {
                    "Verbose" { $IndividualJob | Select-Object -ExpandProperty Verbose| Where-Object { $_.Message } | ForEach-Object { $host.ui.WriteVerboseLine($_)} }                    
                    "Debug" { $IndividualJob | Select-Object -ExpandProperty Debug| Where-Object { $_.Message } | ForEach-Object { $host.ui.WriteDebugLine($_)} }
                    "Warning" { $IndividualJob | Select-Object -ExpandProperty Warning| Where-Object { $_.Message } | ForEach-Object { $host.ui.WriteWarningLine($_) } }
                    "Error"   { $IndividualJob.Error.Exception | Select-Object -ExpandProperty Message | ForEach-Object {$host.ui.WriteErrorLine($_)} }
                    "Output"  { $IndividualJob | Select-Object -ExpandProperty Output }
                }
            }

        }
    }
}