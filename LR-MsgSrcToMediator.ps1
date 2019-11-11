########################################################################################################################
##                                                                                                                    ##
##                                          (c) 2019 Mike Contasti-Isaac                                              ##
##                                                                                                                    ##
##                                                    DISCLAIMER                                                      ##
##                                                                                                                    ##
##                        By using this script, you are assuming all risk and liability of damage                     ##
##                                      that this may cause on relevant systems                                       ##
##                                                                                                                    ##
##                                                                                                                    ##
########################################################################################################################

<#
.SYNOPSIS
    LR-MsgSrcToMediator.ps1 is a powershell script for resolving the LogRhythm Meditor (Data Processor) that a particular log source or list of log sources is sending logs to
.DESCRIPTION
    Requires Powershell 5.0 or later for proper functionality
.NOTES
    Create by: Mike Contasti-Isaac
.PARAMETER LogSourceID
    When the -LogSourceID paramater is used, the script lookup a single log source
.PARAMETER File
    When the -File paramater is used, the script will read a list of log source ids from the provided file
.PARAMETER ServerName
    The servername of the MS SQL database where the LogRhythmEMDB database is stored
.EXAMPLE
    LR-MsgSrcToMediator.ps1 -LogSourceID 1234 -ServerName LogRhythmPMServer
 #>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [int32]$LogSourceID, 
    [Parameter(Mandatory = $true)] [string]$ServerName,
    [Parameter(Mandatory = $false)] [string]$File
)

Function Get-Mediator ($sourceid, $creds) {
    if ($sourceid -notmatch "\d+") {
        $result = [PSCustomObject]@{
            LogSourceID = $sourceid
            LogSourceName = "Invalid ID"
            SMAID = "Invalid ID"
            SMAName ="Invalid ID"
            MediatorID = "Invalid ID"
            MediatorName = "Invalid ID"
        }
        return $result
    }
    else {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.Password)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Try{ 
            $sma = Invoke-Sqlcmd -ServerInstance $ServerName -Database "LogRhythmEMDB" -Username $creds.Username -Password $password -Query "SELECT dbo.MsgSource.SystemMonitorID, dbo.MsgSource.Name FROM dbo.MsgSource WHERE dbo.MsgSource.MsgSourceID=$sourceid;"
            if ($sma -eq $null ) {
                $result = [PSCustomObject]@{
                    LogSourceID = $sourceid
                    LogSourceName = "No results found"
                    SMAID = "No results found"
                    SMAName = "No results found"
                    MediatorID = "No results found"
                    MediatorName = "No results found"
                }
            return $result
            }
            else {                
                $smaID = $sma["SystemMonitorID"].ToString()
                $smaName = Invoke-Sqlcmd -ServerInstance $ServerName -Database "LogRhythmEMDB" -Username $creds.Username -Password $password -Query "SELECT dbo.SystemMonitor.Name FROM dbo.SystemMonitor WHERE dbo.SystemMonitor.SystemMonitorID=$smaID;"
                $mediator = Invoke-Sqlcmd -ServerInstance $ServerName -Database "LogRhythmEMDB" -Username $creds.Username -Password $password -Query "SELECT dbo.Mediator.Name, dbo.Mediator.MediatorID FROM dbo.SystemMonitorToMediator RIGHT JOIN dbo.Mediator ON dbo.SystemMonitorToMediator.MediatorID=dbo.Mediator.MediatorID WHERE dbo.SystemMonitorToMediator.SystemMonitorID=$smaID;"
                $result = [PSCustomObject]@{
                    LogSourceID = $sourceid
                    LogSourceName = $sma["Name"].ToString()
                    SMAID = $smaID
                    SMAName = $smaName["Name"].ToString()
                    MediatorID = $mediator["MediatorID"].ToString()
                    MediatorName = $mediator["Name"].ToString()
                }
            }
        }
        Catch {
            Write-Error "An error occured connecting to the SQL database: $($_)"
            $result = $null
        }
        return $result
    }
}

if (($LogSourceID -eq "") -And ($File -eq "")) {
    Write-Host "Please provide a singe log source ID using the -LogSourceID paramater, or a file containing a list of log source IDs using the -File paramater"
    Exit
}

if (($File -ne $null) -and ($LogSourceID -eq "")) {
    if (-Not (Test-Path -Path $File)) {
        Write-Output "Cannot find the provided file: $($File)"
        Exit
    }
    else {
        $results = @()
        $credents = Get-Credential -Message "Please enter valid SQL credentials"
        Try {
            ForEach($id in Get-Content $File) {
                $results += Get-Mediator $id $credents
            }
        }
        Catch {
            Write-Error "An error occured querying log source IDs: $($_)"
        }
        Write-Output $results | Format-Table -AutoSize
    }
}
elseif (($LogSourceID -ne "") -and ($File -eq "")) {
    $credents = Get-Credential -Message "Please enter valid SQL credentials"
    $results = Get-Mediator $LogSourceID $credents
    Write-Output $results | Format-Table -AutoSize
}
elseif (($Target -ne "") -and ($HostFile -ne "")) {
    Write-Host "Please use either the -LogSourceID paramater or the -File paramater"
    Exit
}