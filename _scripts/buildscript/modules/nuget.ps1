# PowerShell build framework
# Copyright (c) 2015, Yves Goergen, http://unclassified.software/source/psbuild
#
# Copying and distribution of this file, with or without modification, are permitted provided the
# copyright notice and this notice are preserved. This file is offered as-is, without any warranty.

# The nuget module provides NuGet packaging functions.

# Restores all NuGet packages in a solution.
#
# $solutionFile = The file name of the .sln file.
#
# Requires nuget.exe in $toolsPath, %LocalAppData%\NuGet, or the search path.
#
function Restore-NuGetPackages($solutionFile, $time = 0)
{
	$action = @{ action = "Do-Restore-NuGetPackages"; solutionFile = $solutionFile; time = $time }
	$global:actions += $action
}

# Creates a NuGet package.
#
# $specFile = The file name of the .nuspec file.
# $outDir = The output directory of the created package.
#
# Requires nuget.exe in $toolsPath, %LocalAppData%\NuGet, or the search path.
#
function Create-NuGetPackage($specFile, $outDir, $time = 2)
{
	$action = @{ action = "Do-Create-NuGetPackage"; specFile = $specFile; outDir = $outDir; time = $time }
	$global:actions += $action
}

# Uploads a NuGet package to the official package gallery.
#
# $packageFile = The file path and base name of the .nupkg file to upload to the NuGet gallery (excluding version and extension).
# $apiKey = Your API key. If empty, the current user configuration is used.
#
# The API key should be passed from variables that are defined in the private configuration file
# which is excluded from the source code repository. Example:
#
#    Push-NuGetPackage "MyLib" $nuGetApiKey 30
#
# The file _scripts\buildscript\private.ps1 could contain this script:
#
#    $nuGetApiKey = "01234567-89ab-cdef-0123-456789abcdef"
#
# Requires nuget.exe in $toolsPath, %LocalAppData%\NuGet, or the search path.
#
function Push-NuGetPackage($packageFile, $apiKey, $time = 30)
{
	$action = @{ action = "Do-Push-NuGetPackage"; packageFile = $packageFile; apiKey = $apiKey; time = $time }
	$global:actions += $action
}

# ==============================  FUNCTION IMPLEMENTATIONS  ==============================

function Do-Restore-NuGetPackages($action)
{
	$solutionFile = $action.solutionFile
	
	Show-ActionHeader "Restoring NuGet packages for $solutionFile"

	$nugetBin = Find-NuGet

	$textOut = & $nugetBin restore (MakeRootedPath $solutionFile) -NonInteractive 2>&1
	if (-not $?)
	{
		Write-Host $textOut
		WaitError "Restoring NuGet packages failed"
		exit 1
	}
}

function Do-Create-NuGetPackage($action)
{
	$specFile = $action.specFile
	$outDir = $action.outDir

	Show-ActionHeader "Creating NuGet package $specFile"

	$nugetBin = Find-NuGet

	$textOut = & $nugetBin pack (MakeRootedPath $specFile) -OutputDirectory (MakeRootedPath $outDir) -Version $shortRevId -NonInteractive 2>&1
	if (-not $?)
	{
		Write-Host $textOut
		WaitError "Creating NuGet package failed"
		exit 1
	}
}

function Do-Push-NuGetPackage($action)
{
	$packageFile = $action.packageFile
	$apiKey = $action.apiKey

	$packageFile = $packageFile + "." + $shortRevId + ".nupkg"
	
	Show-ActionHeader "Uploading NuGet package $packageFile"

	$nugetBin = Find-NuGet

	if ($apiKey)
	{
		& $nugetBin push (MakeRootedPath $packageFile) -ApiKey $apiKey -NonInteractive -Source https://www.nuget.org/api/v2/package
	}
	else
	{
		& $nugetBin push (MakeRootedPath $packageFile) -NonInteractive -Source https://www.nuget.org/api/v2/package
	}
	if (-not $?)
	{
		WaitError "Uploading NuGet package failed"
		exit 1
	}
}

function Find-NuGet()
{
	# (Tracing messages commented out for debugging purposes)
	#Write-Host "Testing" (Join-Path $absToolsPath "NuGet.exe")
	$nugetBin = Check-FileName (Join-Path $absToolsPath "NuGet.exe")
	if (!$nugetBin)
	{
		#Write-Host "Testing" "$env:LOCALAPPDATA\NuGet\NuGet.exe"
		$nugetBin = Check-FileName "$env:LOCALAPPDATA\NuGet\NuGet.exe"
	}
	if (!$nugetBin)
	{
		# NuGet path: https://github.com/aspnet/Logging/blob/dev/build.cmd
		#Write-Host "Testing" "$env:LOCALAPPDATA\NuGet\NuGet.latest.exe"
		$nugetBin = Check-FileName "$env:LOCALAPPDATA\NuGet\NuGet.latest.exe"
	}
	if (!$nugetBin)
	{
		# Search in %path%
		#Write-Host "Searching NuGet.exe in PATH"
		if (Get-Command "NuGet.exe" -ErrorAction SilentlyContinue)
		{
			$nugetBin = "NuGet.exe"
		}
	}
	if (!$nugetBin)
	{
		Write-Host "Downloading NuGet tool to local cache..."
		try
		{
			$nugetBin = "$env:LOCALAPPDATA\NuGet\NuGet.exe"
			#Write-Host "Creating directory " (Split-Path -parent $nugetBin)
			New-Item -Force -ItemType directory -Path (Split-Path -parent $nugetBin) | Out-Null
			$webclient = New-Object System.Net.WebClient
			$webclient.DownloadFile("https://dist.nuget.org/win-x86-commandline/latest/nuget.exe", $nugetBin)
		}
		catch
		{
			Write-Host $_.Exception.ToString()
			WaitError "Downloading NuGet tool failed"
			exit 1
		}
	}
	return $nugetBin
}
