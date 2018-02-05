Function GetFunctionByFile {
    [CmdletBinding()]
    param (
        [string[]]$FilePath
    )

    $psMajorVersion = $PSVersionTable.PSVersion.Major
    $functionsInFile = @()
    ForEach ($thisFilePath in $FilePath) {
        Write-Verbose "Working on file : $thisFilePath"

        if (-not (Test-Path $thisFilePath)) {
            Write-Warning "Cannot find file : $thisFilePath"
            continue
        }

        try {
            Switch ($psMajorVersion) {
                '2' {
                    $scriptBlockInFile = [ScriptBlock]::Create($(Get-Content $thisFilePath) -join [Environment]::NewLine)
                    $functionsInFile += @(FindFunction -ScriptBlock $scriptBlockInFile)
                }
                Default {
                    $AST = [System.Management.Automation.Language.Parser]::ParseFile($thisFilePath, [ref]$null, [ref]$null)
                    $functionsInFile += $AST.FindAll( {$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]} , $true)
                }
            }
            Write-Verbose "Functions found in file : $($functionsInFile.Name -join '; ')"
        }
        catch {
            Write-Warning "$thisFilePath : $($_.Exception.Message)"
        }
    }
    $functionsInFile
}
