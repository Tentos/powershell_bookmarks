if (Test-Path Variable:\old_prompt) {
    Set-Content -Path "Function:\prompt" -Value $global:old_prompt;
}
Remove-Module Bookmarks -ErrorAction SilentlyContinue;
Import-Module .\Bookmarks.psm1 -Force

class TestClass {
    TestClass() {}
}

InModuleScope Bookmarks {
    function New-FolderInTestDrive([string] $folderName) {
        return New-Item -ItemType Directory -Path TestDrive:\ -Name $folderName;
    }

    function New-FileInTestDrive([string] $fileName) {
        return New-Item -ItemType File -Path TestDrive:\ -Name "${fileName}.txt";
    }

    Describe "Test Bookmark class" {
        $testFolder = Get-Item TestDrive:\;
        $testFile = New-Item -ItemType File -Name "test.it" -Path TestDrive:\;

        Context "Constructors" {
            It "works as expected for existing directories given as DirectoryInfo Object" {
                $testFolder | Should -BeOfType System.IO.DirectoryInfo;
                $testBookmark = [Bookmark]::new("Some bookmark", $testFolder);
    
                $testBookmark.Location | Should -Be $testFolder;
                $testBookmark.Location | Should -BeOfType System.IO.DirectoryInfo;
                $testBookmark.Description | Should -Be "Some bookmark";
                $testBookmark.Description | Should -BeOfType String;
                $testBookmark.Mode | Should -Be "d--";
                $testBookmark.Type | Should -Be Directory;
            }

            It "works as expected for existing directories given as String" {
                $testFolder.FullName | Should -BeOfType String;
                $testBookmark = [Bookmark]::new("Some bookmark", $testFolder.FullName);
    
                $testBookmark.Location | Should -BeLike $testFolder;
                $testBookmark.Location | Should -BeOfType System.IO.DirectoryInfo;
                $testBookmark.Description | Should -Be "Some bookmark";
                $testBookmark.Description | Should -BeOfType String;
                $testBookmark.Mode | Should -Be "d--";
                $testBookmark.Type | Should -Be Directory;
            }

            It "works as expected for existing files given as FileInfo Object" {
                $testFile | Should -BeOfType System.IO.FileInfo;
                $testBookmark = [Bookmark]::new("Some file bookmark", $testFile);

                $testBookmark.Location | Should -Be $testFile;
                $testBookmark.Location | Should -BeOfType System.IO.FileInfo;
                $testBookmark.Description | Should -Be "Some file bookmark";
                $testBookmark.Description | Should -BeOfType String;
                $testBookmark.Mode | Should -Be "-f-";
                $testBookmark.Type | Should -Be File;
            }

            It "works as expected for existing files given as String" {
                $testFile.FullName | Should -BeOfType String;
                $testBookmark = [Bookmark]::new("Some file bookmark", $testFile.FullName);

                $testBookmark.Location | Should -BeLike $testFile;
                $testBookmark.Location | Should -BeOfType System.IO.FileInfo;
                $testBookmark.Description | Should -Be "Some file bookmark";
                $testBookmark.Description | Should -BeOfType String;
                $testBookmark.Mode | Should -Be "-f-";
                $testBookmark.Type | Should -Be File;
            }

            It "accepts a non-existing <pathType>-type location and saves it as bookmark type 'Unknown'" -TestCases @(
                @{ pathType = "File"; pathLeaf = "nonExistingFile.txt" }
                @{ pathType = "Directory"; pathLeaf = "nonExistingDirectory" }
            ) {
                param($pathType, $pathLeaf)
                $nonExistingPath = Join-Path $testDrive $pathLeaf;
                $nonExistingPath | Should -BeOfType String;
                $testBookmark = [Bookmark]::new("Some non-existing path", $nonExistingPath);

                $testBookmark.Location | Should -BeLike $nonExistingPath;
                $testBookmark.Location | Should -BeOfType System.IO.FileInfo;
                $testBookmark.Description | Should -Be "Some non-existing path";
                $testBookmark.Description | Should -BeOfType String;
                $testBookmark.Mode | Should -Be "--u";
                $testBookmark.Type | Should -Be Unknown;
            }
        }

        Context "Constructor error handling" {
            It "does not accept an empty string as Description" {
                {[Bookmark]::new("", $testFolder)} | Should -Throw;
            }
    
            It "does not accept `$null as Description" {
                {[Bookmark]::new($null, $testFolder)} | Should -Throw;
            }

            It "does not accept an empty string as Location" {
                {[Bookmark]::new("test bookmark", "")} | Should -Throw "Location is missing in constructor of class 'Bookmark'";
            }

            It "does not accept `$null as Location" {
                {[Bookmark]::new("test bookmark", $null)} | Should -Throw;                
            }
        }

        Context "Reserialization" {
            It "its reserialize method converts a deserialized bookmark into a Bookmark object" {
                $pseudoDeserializedBookmark = [psobject]::new([Bookmark]::new("testDescription", $testDrive))
    
                $serializedBookmark = [Bookmark]::reserialize($pseudoDeserializedBookmark);
    
                $serializedBookmark -Is [Bookmark] | Should -Be $true;
                $serializedBookmark.description | Should -Be "testDescription";
                $serializedBookmark.location | Should -BeLike $testDrive;
            }

            It "its reserialize method throws an exception if a deserialized object of wrong class is given" {
                $pseudoDeserializedTestClass = [psobject]::new([TestClass]::new());
    
                {[Bookmark]::reserialize($pseudoDeserializedTestClass)} | Should -Throw "Given deserialized PSObject is not of type 'Bookmark', but of type 'TestClass'";
            }
        }

        Context "Location target change induces Mode and Type attribute changes" {
            BeforeEach {
                $Bookmarks.Clear();
                Get-ChildItem $testDrive | Remove-Item;
            }

            It "<oldTargetType> -> <newTargetType>" -TestCases @(
                @{oldTargetType = "File"; oldTargetMode = "-f-"; newTargetType = "Directory"; newTargetMode = "d--"}
                @{oldTargetType = "Directory"; oldTargetMode = "d--"; newTargetType = "File"; newTargetMode = "-f-"}
            ) {
                Param($oldTargetType, $oldTargetMode, $newTargetType, $newTargetMode)
                $testItem = New-Item -ItemType $oldTargetType -Path TestDrive:\ -Name "test.old";
                New-Bookmark "Test" -Location $testItem;

                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be $oldTargetMode;
                $testBookmark.Type | Should -Be $oldTargetType;

                Remove-Item $testItem;

                $testItem = New-Item -ItemType $newTargetType -Path TestDrive:\ -Name "test.old";
                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be $newTargetMode;
                $testBookmark.Type | Should -Be $newTargetType;
            }

            It "Location does not exist -> <newTargetType>" -TestCases @(
                @{newTargetType = "Directory"; newTargetMode = "d--"}
                @{newTargetType = "File"; newTargetMode = "-f-"}
            ) {
                Param($newTargetType, $newTargetMode)
                $testPath = Join-Path $testDrive "test.old";
                New-Bookmark "Test" -Location $testPath;

                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be "--u";
                $testBookmark.Type | Should -Be Unknown;

                New-Item -ItemType $newTargetType -Path TestDrive:\ -Name "test.old";
                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be $newTargetMode;
                $testBookmark.Type | Should -Be $newTargetType;
            }

            It "<oldTargetType> -> Location does not exist" -TestCases @(
                @{oldTargetType = "Directory"; oldTargetMode = "d--"}
                @{oldTargetType = "File"; oldTargetMode = "-f-"}
            ) {
                Param($oldTargetType, $oldTargetMode)
                $testItem = New-Item -ItemType $oldTargetType -Path TestDrive:\ -Name "test.old";
                New-Bookmark "Test" -Location $testItem;

                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be $oldTargetMode;
                $testBookmark.Type | Should -Be $oldTargetType;

                Remove-Item $testItem;
                $testBookmark = Get-Bookmark "Test";
                ($testBookmark).Length | Should -Be 1;
                $testBookmark.Mode | Should -Be "--u";
                $testBookmark.Type | Should -Be Unknown;
            }
        }
    }

    Describe "Prompt" {
        $dirSeparator = [System.IO.Path]::DirectorySeparatorChar;

        $withoutEndingBackslashFolder = New-FolderInTestDrive "folderAlpha";
        $withoutEndingBackslashFolderPath = Resolve-Path $withoutEndingBackslashFolder;

        $withEndingBackslashFolder = New-FolderInTestDrive "folderGamma";
        $withEndingBackslashFolderPath = Resolve-Path ([string]::Concat(($withEndingBackslashFolder.ToString().TrimEnd($dirSeparator)), $dirSeparator));
        
        $nestedFolderWithBookmark = New-Item -ItemType Directory -Path $withEndingBackslashFolder -Name "folderDelta";
        $nestedFolderWithBookmarkPath = Resolve-Path $nestedFolderWithBookmark;
        
        $nestedFolderWithoutBookmark = New-Item -ItemType Directory -Path $withEndingBackslashFolder -Name "folderEpsilon";
        $nestedFolderWithoutBookmarkPathNoSlash = Resolve-Path $nestedFolderWithoutBookmark;
        $nestedFolderWithoutBookmarkPathSlash = Resolve-Path ([string]::Concat($nestedFolderWithoutBookmark, $dirSeparator));
        
        $rootPath = Resolve-Path "/";
        
        $fileBeta = New-FileInTestDrive "fileBeta";

        New-Bookmark "Folder With $dirSeparator" -Location $withoutEndingBackslashFolder;
        New-Bookmark "Nested Bookmark folder" -Location $nestedFolderWithBookmark;
        New-Bookmark "File Beta" -Location $fileBeta;
        New-Bookmark "Without $dirSeparator folder" -Location $withEndingBackslashFolder;
        New-Bookmark "Root" -Location $rootPath;
        
        Context "Current location is part of bookmarks" {
            $withoutEndingBackslashFolderPath.Path.EndsWith($dirSeparator) | Should -Be $false;
            $withEndingBackslashFolderPath.Path.EndsWith($dirSeparator) | Should -Be $true;
            $rootPath.Path.EndsWith($dirSeparator) | Should -Be $true;

            It "shows the bookmark description in the prompt for <Description>" -TestCases @(
                @{ getLocation = $withoutEndingBackslashFolderPath ; Description = "Folder With $dirSeparator" }
                @{ getLocation = $withEndingBackslashFolderPath ; Description = "Without $dirSeparator folder" }
                @{ getLocation = $nestedFolderWithBookmarkPath ; Description = "Nested Bookmark folder" }
                @{ getLocation = $rootPath ; Description = "Root" }
            ) {
                param($getLocation, $Description)
                Mock -CommandName Invoke-Command -MockWith {"PS Prompt > "};
                Mock -CommandName Get-Location -MockWith { $getLocation };
                Mock -CommandName Write-Host {};

                prompt | Should -Be "PS Prompt > ";
                Assert-MockCalled -CommandName Write-Host -ParameterFilter {($Object -eq "[$Description] ") -and ($NoNewLine -eq $true) -and ($ForeGroundColor -eq "Cyan")}
            }
        }

        Context "Current location is not part of bookmarks" {
            It "shows only normal prompt - path has ending slash: <hasSlash>" -TestCases @(
                @{ getLocation = $nestedFolderWithoutBookmarkPathNoSlash ; hasSlash = $false }
                @{ getLocation = $nestedFolderWithoutBookmarkPathSlash ; hasSlash = $true }
            ) {
                param($getLocation, $hasSlash)
                $getLocation.Path.EndsWith($dirSeparator) | Should -Be $hasSlash;

                Mock -CommandName Invoke-Command -MockWith {"PS Prompt > "};
                Mock -CommandName Get-Location -MockWith { $getLocation };
                Mock -CommandName Write-Host {};

                prompt | Should -Be "PS Prompt > ";
                Assert-MockCalled -CommandName Write-Host -ParameterFilter {($Object -eq $null) -and ($NoNewLine -eq $true) -and ($ForeGroundColor -eq "Cyan")}
            }
        }
    }
}