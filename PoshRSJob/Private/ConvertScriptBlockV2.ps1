Function ConvertScriptBlockV2 {
    Param (
        [scriptblock]$ScriptBlock,
        [bool]$HasParam,
        $UsingVariables,
        $UsingVariableValues,
        [bool]$InsertPSItem = $false
    )
    # $UsingVariables unused
    $errors = [System.Management.Automation.PSParseError[]] @()
    $Tokens = [Management.Automation.PsParser]::Tokenize($ScriptBlock.tostring(), [ref] $errors)
    $StringBuilder = New-Object System.Text.StringBuilder
    $UsingHash = @{}
    $UsingVariableValues | ForEach-Object {
        $UsingHash["Using:$($_.Name)"] = $_.NewVarName
    }
    $Params = New-Object System.Collections.ArrayList
    If ($InsertPSItem) {
        [void]$Params.Add('$_')
    }
    If ($UsingVariableValues) {
        [void]$Params.AddRange(@($UsingVariableValues | Select-Object -ExpandProperty NewName))
    }
    $NewParams = $Params -join ', '  
    If (-Not $HasParam) {
        [void]$StringBuilder.Append("Param($($NewParams))")
    }
    For ($i=0;$i -lt $Tokens.count; $i++){
        #Write-Verbose "Type: $($Tokens[$i].Type)"
        #Write-Verbose "Previous Line: $($Previous.StartLine) -- Current Line: $($Tokens[$i].StartLine)"
        If ($Previous.StartLine -eq $Tokens[$i].StartLine) {
            $Space = " " * [int]($Tokens[$i].StartColumn - $Previous.EndColumn)
            [void]$StringBuilder.Append($Space)
        }
        Switch ($Tokens[$i].Type) {
            'NewLine' {[void]$StringBuilder.Append("`n")}
            'Variable' {
                If ($UsingHash[$Tokens[$i].Content]) {
                    [void]$StringBuilder.Append(("`${0}" -f $UsingHash[$Tokens[$i].Content]))
                } Else {
                    [void]$StringBuilder.Append(("`${0}" -f $Tokens[$i].Content))
                }
            }
            'String' {
                $qchar = $ScriptBlock.ToString().Split("`n")[($Tokens[$i].StartLine-1)].Substring($Tokens[$i].StartColumn-1,1)
                [void]$StringBuilder.Append(("{0}{1}{0}" -f $qchar,$Tokens[$i].Content))
            }
            'GroupStart' {
                $Script:GroupStart++
                If ($Script:AddUsing -AND $Script:GroupStart -eq 1) {
                    $Script:AddUsing = $False
                    [void]$StringBuilder.Append($Tokens[$i].Content)                    
                    If ($HasParam) {
                        [void]$StringBuilder.Append("$($NewParams),")
                    }
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }
            }
            'GroupEnd' {
                $Script:GroupStart--
                If ($Script:GroupStart -eq 0) {
                    $Script:Param = $False
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }
            }
            'KeyWord' {
                If ($Tokens[$i].Content -eq 'Param') {
                    $Script:Param = $True
                    $Script:AddUsing = $True
                    $Script:GroupStart=0
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }                
            }
            'Type' {
                [void]$StringBuilder.Append('[{0}]' -f $Tokens[$i].Content)
            }
            Default {
                [void]$StringBuilder.Append($Tokens[$i].Content)         
            }
        } 
        $Previous = $Tokens[$i]   
    }
    #$StringBuilder.ToString()
    [scriptblock]::Create($StringBuilder.ToString())
}
