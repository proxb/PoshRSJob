#region Custom Argument Completors
#Global variables are required for this functionality (Invoke-ScriptAnalyzer)
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "global:options")]
param()

#region Job ID
$completion_ID = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    Get-RSJob | Sort-Object -Property Id | Where-Object { $_.Id -like "$wordToComplete*" } |ForEach-Object {
        New-Object System.Management.Automation.CompletionResult $_.Id, $_.Id, 'ParameterValue', ('{0} ({1})' -f $_.Description, $_.ID) 
    }
}
#endregion Job ID
#region Job Name
$completion_Name = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    Get-RSJob | Sort-Object -Property Name | Where-Object { $_.Name -like "$wordToComplete*" } |ForEach-Object {
        New-Object System.Management.Automation.CompletionResult $_.Name, $_.Name, 'ParameterValue', ('{0} ({1})' -f $_.Description, $_.ID) 
    }
}
#endregion Job Name
If (-not (Get-Variable -Scope Global | Where-Object {$_.Name -eq "options"})) { 
    $global:options = @{
        CustomArgumentCompleters = @{}
        NativeArgumentCompleters = @{}
    }
}

$global:options['CustomArgumentCompleters']['Get-RSJob:Id'] = $completion_ID
$global:options['CustomArgumentCompleters']['Get-RSJob:Name'] = $completion_Name
$global:options['CustomArgumentCompleters']['Remove-RSJob:Id'] = $completion_ID
$global:options['CustomArgumentCompleters']['Remove-RSJob:Name'] = $completion_Name
$global:options['CustomArgumentCompleters']['Stop-RSJob:Id'] = $completion_ID
$global:options['CustomArgumentCompleters']['Stop-RSJob:Name'] = $completion_Name
$global:options['CustomArgumentCompleters']['Receive-RSJob:Id'] = $completion_ID
$global:options['CustomArgumentCompleters']['Receive-RSJob:Name'] = $completion_Name

if (Get-Item function:tabexpansion[2]) {
    $function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End { if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'
}
#endregion Custom Argument Completors
