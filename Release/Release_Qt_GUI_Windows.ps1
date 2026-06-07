##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license that can
##  be found in the License.html file in the root of the source tree.
##

Param(
    [parameter(Mandatory=$true)][String]$arch,
    [String]$msvc = "MSVC2022"
)

$ErrorActionPreference = "Stop"

#-----------------------------------------------------------------------
# Setup
$release_directory = $PSScriptRoot
$version = (Get-Content "${release_directory}\..\Project\version.txt" -Raw).Trim()

switch ($msvc) {
    "MSVC2022" {
        $vc = "vc17"
        $sln = "sln"
        break
    }
    "MSVC2026" {
        $vc = "vc18"
        $sln = "slnx"
        break
    }
    Default { throw "Invalid parameter: '$msvc'." }
}

#-----------------------------------------------------------------------
# Cleanup
$artifact = "${release_directory}\MediaInfo_Qt_Windows_${arch}"
if (Test-Path "${artifact}") {
    Remove-Item -Force -Recurse "${artifact}"
}

$artifact = "${release_directory}\MediaInfo_Qt_Windows_${arch}_WithoutInstaller.7z"
if (Test-Path "${artifact}") {
    Remove-Item -Force "${artifact}"
}

$artifact = "${release_directory}\MediaInfo_Qt_Windows_${arch}.msix"
if (Test-Path "${artifact}") {
    Remove-Item -Force "${artifact}"
}

#-----------------------------------------------------------------------
# Package GUI
Push-Location "${release_directory}"
    New-Item -Force -ItemType Directory -Path "MediaInfo_Qt_Windows_${arch}"
    Push-Location "MediaInfo_Qt_Windows_${arch}"
        ### Copying: Exe ###
        Copy-Item -Force "..\..\Project\QMake\GUI\build\Desktop_Qt_${msvc}_${arch}-Release\${arch}\MediaInfo.exe" .
        ### Deploy: Qt ###
        $processArch = "$arch".ToLower()
        $osArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()
        if ($processArch -ne $osArch) {
            $qtpaths = Get-Command host-qtpaths.bat
            windeployqt --qtpaths "$($qtpaths.Path)" --no-quick-import --no-translations --no-system-d3d-compiler --no-system-dxc-compiler --no-compiler-runtime --no-opengl-sw "$($PWD.Path)\MediaInfo.exe"
        } else {
            windeployqt --no-quick-import --no-translations --no-system-d3d-compiler --no-system-dxc-compiler --no-compiler-runtime --no-opengl-sw "$($PWD.Path)\MediaInfo.exe"
        }
        ### Copying: WebView2Loader ###
        Copy-Item -Force "..\..\Project\QMake\GUI\packages\Microsoft.Web.WebView2\build\native\${arch}\WebView2Loader.dll" .
        ### Copying: Shell Extension ###
        Copy-Item -Force "..\..\Project\${msvc}\MediaInfo_WindowsShellExtension\${arch}\Release Qt\MediaInfo_WindowsShellExtension.dll" .
        ### Copying: libcurl ###
        Copy-Item -Force "..\..\..\libcurl\${arch}\Release\libcurl.dll" .
        ### Copying: Graphviz ###
        Copy-Item -Force -Recurse "..\..\..\Graphviz\${arch}\*" .
        ### Copying: FFmpeg ###
        Copy-Item -Force "..\..\..\FFmpeg\${arch}\ffmpeg.exe" .
        ### Copying: Information files ###
        Copy-Item -Force "..\..\License.html" .
        Copy-Item -Force "..\..\History_GUI.txt" "History.txt"
        Copy-Item -Force "..\Readme_GUI_Windows.txt" "ReadMe.txt"
        ### Archive
        7za.exe a -r -t7z -mx9 "..\MediaInfo_Qt_Windows_${arch}_WithoutInstaller.7z" *
        ### Copying: Package Resources ###
        Copy-Item -Force -Recurse "..\..\Source\WindowsQtPackage\*" .
        ### Updating: Package ProcessorArchitecture ###
        $filePath = "$($PWD.Path)\AppxManifest.xml"
        $arch_lower = $arch.ToLower()
        $content = (Get-Content $filePath -Raw) -replace '@@arch@@', "${arch_lower}"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
    Pop-Location
Pop-Location

#-----------------------------------------------------------------------
# Package MSIX
MakeAppx pack /d "${release_directory}\MediaInfo_Qt_Windows_${arch}\" /p "${release_directory}\MediaInfo_Qt_Windows_${arch}.msix" /o
