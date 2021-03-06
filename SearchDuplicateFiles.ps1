#requires -Version 5
# the correct synthase is "#requires -Version 5" with the # before. Change the -Version number by the version required by your script's cmdlets

<#
    .NOTES
    --------------------------------------------------------------------------------
    Code generated by:  MS Visual Studio Code
    Generated on:       02/04/2018
    Generated by:       SP@2018
    Organization:       SIK-NET
    --------------------------------------------------------------------------------
    .SYNOPSIS
    Search Duplicated Files
    .DESCRIPTION
    Search Duplicated files by size and Hash MD5

    Versionning
    V1.0 - 02/04/2018 - SP@: Creation
#>



## MODULES
$OutputEncoding = [Console]::OutputEncoding

## VARIABLES
$Path1 = "Z:\SeriesTV" # G:\_Serie Z:\SeriesTV
$Path2 = ""

$MaxThreads = 3 # RunSpace Pool Max Size
$Result = @() # Create a table for the result
$Jobs = @() # Create a table for Jobs

## FUNCTIONS
function Get-MD5 {
    <#
    .SYNOPSIS
    Get the MD5 Hash result of the file
    .DESCRIPTION
    The function return the hash of the file

    This Get-MD5 function sourced from:
    http://blogs.msdn.com/powershell/archive/2006/04/25/583225.aspx
    .PARAMETER Fullname
    Short Resume of the Variable job
    .EXAMPLE
    Get-MD5 "C:\temp\test.avi"

    Return the MD5 hash for the file test.avi

    .EXAMPLE
    Gci c:\temp\ | ForEach-Object {Get-MD5 $_.fullname}

    Return the MD5 hash for file received in the pipe

    #>
    [Cmdletbinding()]
    Param (
        [Parameter(Mandatory = $True,Position = 0,ValueFromPipeLine=$true)][String]$Fullname
    )
    Process
    {
        $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        $Stream = [System.IO.File]::OpenRead($Fullname)
        try {
            $HashByteArray = $HashAlgorithm.ComputeHash($Stream)
        } finally {
            $Stream.Dispose()
        }
    
        return [System.BitConverter]::ToString($HashByteArray).ToLowerInvariant() -replace '-',''
    }
}

## SCRIPT

# Create a RunSpace Pool
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()
# ----------------------

$FilesGroups = Get-ChildItem -Recurse -File $Path1, $Path2 | Group-Object -Property Length

foreach($FileGroup in $FilesGroups)
{
    if ($FileGroup.Count -ne 1 -And [convert]::ToInt64(($FileGroup.Name),10) -gt 1MB)
    {
        foreach ($File in $FileGroup.Group)
        {
            Write-Host -ForegroundColor Green "$($File.Name)"
            $ScriptBlock = {
                Param (
                    $FileObject
                 )
                function Get-MD5 {
                    [Cmdletbinding()]
                    Param (
                        [Parameter(Mandatory = $True,Position = 0,ValueFromPipeLine=$true)][String]$Fullname
                    )
                    Process
                    {
                        $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                        $Stream = [System.IO.File]::OpenRead($Fullname)
                        try {
                            $HashByteArray = $HashAlgorithm.ComputeHash($Stream)
                        } finally {
                            $Stream.Dispose()
                        }
                    
                        return [System.BitConverter]::ToString($HashByteArray).ToLowerInvariant() -replace '-',''
                    }
                }
                
                $FileResult = new-object Psobject # Create an object of the table
                $FileResult | Add-member -Name "Name" -Membertype "Noteproperty" -Value $($FileObject.Name)
                $FileResult | Add-member -Name "MD5" -Membertype "Noteproperty" -Value $(Get-MD5 $FileObject.FullName)
                $FileResult | Add-member -Name "Length" -Membertype "Noteproperty" -Value $([convert]::ToInt64($($FileObject.Length),10)/1MB)
                $FileResult | Add-member -Name "FullName" -Membertype "Noteproperty" -Value $($FileObject.FullName)

                return $FileResult
            }
            $ArgumentList = @($File)
            # Create the Job in the RunSpace
            $Job = [powershell]::Create().AddScript($ScriptBlock).AddParameters($ArgumentList)
            $Job.RunspacePool = $RunspacePool # Assign the job to the RunSpace Pool
            $Jobs += New-Object PSObject -Property @{
                File = $File
                Pipe = $Job
                Result = $Job.BeginInvoke() # Start the Job
            }
        }    
    }
}
# Waiting for the end of jobs
Write-Host "Waiting.." -NoNewline
While ( (($jobs | ForEach-Object { $_.result }) | Select-Object -ExpandProperty IsCompleted) -contains $false ) {
    $NbOfJobs= ($Jobs | Measure-Object).count
    $NbOfOngoingJobs = 0
    $jobs | ForEach-Object {
        if(($_.result).IsCompleted -eq $True)
        {
            $NbOfOngoingJobs++
        }
    }
    Write-Host ".$NbOfOngoingJobs\$NbOfJobs." -NoNewline
    Start-Sleep -Seconds 10
}
ForEach ($Job in $Jobs)
{   
    $Result += $Job.Pipe.EndInvoke($Job.Result) # Receive the Job Result and Close the Job
}
$RunspacePool.Close() # Closing the RunSpace Pool

# Group by the the Hash
$FilesGroups = $Result | Group-Object -Property MD5

# Reset Variable
$Result = @()

foreach($FileGroup in $FilesGroups)
{
    if ($FileGroup.Count -gt 1)
    {
        foreach ($File in $FileGroup.Group)
        {
            $FileResult = new-object Psobject # Create an object of the table
            $FileResult | Add-member -Name "Name" -Membertype "Noteproperty" -Value $($File.Name)
            $FileResult | Add-member -Name "MD5" -Membertype "Noteproperty" -Value $($File.MD5)
            $FileResult | Add-member -Name "Length" -Membertype "Noteproperty" -Value $($File.Length)
            $FileResult | Add-member -Name "FullName" -Membertype "Noteproperty" -Value $($File.FullName)
            $FileResult | Add-member -Name "Directory" -Membertype "Noteproperty" -Value $(($File.Fullname).Replace($($File.Name),""))

            $Result += $FileResult
        }
    }
}

$Result | Out-GridView
Read-Host "Press any key"
#EOF