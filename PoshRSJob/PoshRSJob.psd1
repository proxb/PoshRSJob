
#
# PoshRSJob
# Version 1.7.4.4
#
# Boe Prox (c) 2014
# http://learn-powershell.net
#
#################################

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = 'PoshRSJob.psm1'

# Version number of this module.
ModuleVersion = '1.7.4.4'

# ID used to uniquely identify this module
GUID = '9b17fb0f-e939-4a5c-b194-3f2247452972'

# Author of this module
Author = 'Boe Prox'

# Company or vendor of this module
CompanyName = 'NA'

# Copyright statement for this module
Copyright = '(c) 2014 Boe Prox. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Module designed to use PowerShell runspaces to create jobs that allow throttling and quicker execution of commands'

# Minimum version of the Windows PowerShell engine required by this module
#PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
#PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
#PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
#DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
#CLRVersion = ''

# Processor architecture (None, X86, Amd64, IA64) required by this module
#ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
#RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
#RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @('Scripts\TabExpansion.ps1')

# Type files (.ps1xml) to be loaded when importing this module
#TypesToProcess = 'TypeData\PoshRSJob.Types.ps1xml'

# Format files (.ps1xml) to be loaded when importing this module
#FormatsToProcess = 'TypeData\PoshRSJob.Format.ps1xml'

# Modules to import as nested modules of the module specified in ModuleToProcess
#NestedModules = @()

# Functions to export from this module
FunctionsToExport = 'Get-RSJob','Receive-RSJob','Remove-RSJob',
    'Start-RSJob','Stop-RSJob','Wait-RSJob'

# Cmdlets to export from this module
#CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = 'PoshRS_Jobs','PoshRS_JobCleanup','PoshRS_JobID','PoshRS_RunspacePools','PoshRS_RunspacePoolCleanup'

# Aliases to export from this module
AliasesToExport = 'gsj','rmsj','rsj','spsj','ssj','wsj'

# List of all modules packaged with this module
#ModuleList = @()

# List of all files packaged with this module
FileList = 'PoshRSJob.psd1', 'PoshRSJob.psm1', 'en-US\about_PoshRSJob.help.txt', 'Private\ConvertScript.ps1', 'Private\ConvertScriptBlockV2.ps1',
'Private\FindFunction.ps1', 'Private\GetFunctionByFile.ps1', 'Private\GetFunctionDefinitionByFunction.ps1', 'Private\GetParamVariable.ps1', 'Private\GetUsingVariables.ps1', 'Private\GetUsingVariablesV2.ps1',
'Private\Increment.ps1', 'Private\RegisterScriptScopeFunction.ps1', 'Public\Get-RSJob.ps1', 'Public\Receive-RSJob.ps1',
'Public\Remove-RSJob.ps1', 'Public\Start-RSJob.ps1', 'Public\Stop-RSJob.ps1', 'Public\Wait-RSJob.ps1', 'TypeData\PoshRSJob.Format.ps1xml', 'TypeData\PoshRSJob.Types.ps1xml',
'Private\SetIsReceived.ps1'

# Private data to pass to the module specified in ModuleToProcess
PrivateData = @{
    PSData = @{
			# The primary categorization of this module (from the TechNet Gallery tech tree).
			Category = "Multithreading"

			# Keyword tags to help users find this module via navigations and search.
			Tags = @('PoshRSJob', 'Runspace','RunspacePool', 'Linux', 'PowerShellCore', 'RSJob')

			# The web address of an icon which can be used in galleries to represent this module
			#IconUri = ''

			# The web address of this module's project or support homepage.
			ProjectUri = "https://github.com/proxb/PoshRSJob"

			# The web address of this module's license. Points to a page that's embeddable and linkable.
			LicenseUri = "https://opensource.org/licenses/MIT"

			# Release notes for this particular version of the module
			# ReleaseNotes = False

			# If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
			RequireLicenseAcceptance = "False"

			# Indicates this is a pre-release/testing version of the module.
			IsPrerelease = 'False'
		}
    }
}
