Function WriteStream {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [Object]$IndividualJob
    )

    Process {
        #First write the verbose stream...
        Write-Verbose $IndividualJob.Verbose

        #Write the warning stream...
        Write-Warning $IndividualJob.Warning

        #Write the error stream...
        Write-Error $IndividualJob.Error

        #Write StdOut
        Write-Output $IndividualJob.Output
    }
}