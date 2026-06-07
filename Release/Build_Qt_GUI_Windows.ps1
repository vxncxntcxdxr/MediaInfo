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

switch ($arch) {
    "x64" {
        $qt_spec = "win32-msvc"
        break
    }
    "ARM64" {
        $qt_spec = "win32-arm64-msvc"
        break
    }
    Default { throw "Unsupported arch: '$arch'." }
}

#-----------------------------------------------------------------------
# Build
### Build: MediaInfo DLL ###
Push-Location -Path "${release_directory}\..\..\MediaInfoLib\Project\${msvc}"
    MSBuild "-p:Configuration=Release;Platform=${arch}" MediaInfoLib.${sln}
Pop-Location

### Build: Windows Shell Extension ###
Push-Location -Path "${release_directory}\..\Project\${msvc}\MediaInfo_WindowsShellExtension"
    MSBuild -restore -p:RestorePackagesConfig=true -t:Build "-p:Configuration=Release Qt" -p:Platform=${arch} MediaInfo_WindowsShellExtension.vcxproj
Pop-Location

### Build: Image assets and resources ###
xcopy "${release_directory}\..\Source\Resource\Image\MSIX_Assets" "${release_directory}\..\Source\WindowsQtPackage\Assets\" /i /e /r /y
Push-Location -Path "${release_directory}\..\Source\WindowsQtPackage"
    makepri new /o /pr "${release_directory}\..\Source\WindowsQtPackage" /cf "${release_directory}\..\Source\WindowsQtPackage\priconfig.xml"
Pop-Location

### Build: Qt GUI ###
New-Item -Force -ItemType Directory "${release_directory}\..\Project\QMake\GUI\build\Desktop_Qt_${msvc}_${arch}-Release"
pushd "${release_directory}\..\Project\QMake\GUI\build\Desktop_Qt_${msvc}_${arch}-Release"
    $processArch = "$arch".ToLower()
    $osArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()
    if ($processArch -ne $osArch) {
        host-qmake ..\..\MediaInfoQt.pro -spec ${qt_spec} "CONFIG+=qtquickcompiler"
    } else {
        qmake ..\..\MediaInfoQt.pro -spec ${qt_spec} "CONFIG+=qtquickcompiler"
    }
    jom.exe
    jom.exe clean
Pop-Location
