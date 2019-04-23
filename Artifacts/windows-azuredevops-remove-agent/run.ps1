# Downloads the Azure DevOps Pipelines Agent and installs specified instances on the new machine
# under C:\agents\ and registers with the Azure DevOps Pipelines agent pool

[CmdletBinding()]
Param
(
    [Parameter()]
    [String]$PersonalAccessToken,

    [Parameter()]
    [string]$AgentName,

    [Parameter()]
    [string]$AgentInstallLocation
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#
trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $error[0].Exception.Message
    if ($message) {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

#
# Test the last exit code correctly.
#
function Test-LastExitCode {
    param
    (
        [string] $Message = ''
    )

    # Whenever we execute commands such as '& somecommand' or via Invoke-Expression, we should always
    # check the exit code, so we can decide to stop processing at that time, by throwing an exception.
    $exitCode = $LASTEXITCODE
    if ($exitCode -and $exitCode -ne 0) {
        if ($Message) {
            if (-not $Message.EndsWith('.')) {
                $Message += '.'
            }
            $Message += ' '
        }
        $Message += "Last command exited with error code $exitCode"
        throw $Message
    }
    Write-Output "Completed with exit code: $exitCode"
}
###################################################################################################
#
# Main execution block.
#
try {
    Write-Output "Entering powershell task" 
    Write-Output "Current folder: $PSScriptRoot" 

    Write-Output "Validating parameters..."

    if ([string]::IsNullOrWhiteSpace($PersonalAccessToken)) {
        throw "PersonalAccessToken parameter is required."
    }
    if ([string]::IsNullOrWhiteSpace($AgentName)) {
        throw "AgentName parameter is required."
    }
    if ([string]::IsNullOrWhiteSpace($AgentInstallLocation)) {
        $AgentInstallLocation = "c:\agents";
    }

    # Construct the agent folder under the main (hardcoded) C: drive.
    $agentInstallationPath = Join-Path $AgentInstallLocation $AgentName

    # Retrieve the path to the config.cmd file.
    $agentConfigPath = [System.IO.Path]::Combine($agentInstallationPath, 'config.cmd')
    Write-Output "Agent Location = $agentConfigPath" 
    if (![System.IO.File]::Exists($agentConfigPath)) {
        throw "File not found: $agentConfigPath"
    }

    # Call the agent with the configure command and all the options (this creates the settings file) without prompting
    # the user or blocking the cmd execution
    Write-Output "Configuring agent '$($AgentName)'"
    .\config.cmd remove --unattended --auth PAT --token $PersonalAccessToken
    Test-LastExitCode

    Pop-Location

    Write-Output "Exiting RemoveAgent.ps1" 
}
catch {
    $exceptionText = ($_ | Out-String).Trim()
    Write-Output "Exception occured while removing agent: $exceptionText" 
    $retries++
    Start-Sleep -Seconds 30 
}
finally {
    Pop-Location
}

