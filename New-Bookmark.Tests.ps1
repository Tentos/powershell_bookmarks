if (Test-Path Variable:\old_prompt) {
    Set-Content -Path "Function:\prompt" -Value $global:old_prompt;
}
Remove-Module Bookmarks -ErrorAction SilentlyContinue;
Import-Module .\Bookmarks.psm1 -Force

InModuleScope Bookmarks {
    function New-FolderInTestDrive([string] $folderName) {
        return New-Item -ItemType Directory -Path TestDrive:\ -Name $folderName;
    }

    function New-FileInTestDrive([string] $fileName) {
        return New-Item -ItemType File -Path TestDrive:\ -Name "${fileName}.txt";
    }
    Describe "New-Bookmark" {

        BeforeEach {
            Push-Location $(Get-Location) -StackName UnitTesting;
        }
    
        AfterEach {
            Pop-Location -StackName UnitTesting;
        }

        [scriptblock] $checkDirectoryBookmark = {
            Param([int] $i, $expectedType)
            $testLocation | Should -BeOfType $expectedType;

            $Bookmarks | Should -Not -BeNullOrEmpty;
            $Bookmarks.Count | Should -Be $i;

            $Bookmarks.Item($i - 1).location | Should -BeLike $testLocation;
            $Bookmarks.Item($i - 1).description | Should -Be "Test Location $i";
            $Bookmarks.Item($i - 1).Mode | Should -Be "d--";
            $Bookmarks.Item($i - 1).Type | Should -Be Directory;
        }

        Context "with given directory location" {
            $Script:Bookmarks.Clear();

            It "adds a bookmark to the bookmark list" {
                $testLocation = New-FolderInTestDrive "Test Folder 1";
                New-Bookmark -location $testLocation -description "Test Location 1";

                $checkDirectoryBookmark.Invoke(1, "System.IO.DirectoryInfo")
            }

            It "adds a second bookmark to the bookmark list" {
                $testLocation = New-FolderInTestDrive "Test Folder 2";
                New-Bookmark -location $testLocation -description "Test Location 2";

                $checkDirectoryBookmark.Invoke(2, "System.IO.DirectoryInfo")
            }

            It "adds a bookmark with path given as String to the bookmark list" {
                $testLocation = New-FolderInTestDrive "Test Folder 3";
                $testLocation = $testLocation.FullName;
                New-Bookmark -location $testLocation -description "Test Location 3";

                $checkDirectoryBookmark.Invoke(3, "String")
            }

            It "adds a bookmark with directory path given as PathInfo to the bookmark list" {
                $testLocation = New-FolderInTestDrive "Test Folder 4";
                $testLocation = Resolve-Path $testLocation;
                New-Bookmark $testLocation -description "Test Location 4";

                $checkDirectoryBookmark.Invoke(4, "System.Management.Automation.PathInfo")
            }
        }

        [scriptblock] $checkFileBookmark = {
            Param([int] $i, $expectedType)
            $testLocation | Should -BeOfType $expectedType;
        
            $Bookmarks | Should -Not -BeNullOrEmpty;
            $Bookmarks.Count | Should -Be $i;
        
            $Bookmarks.Item($i - 1).location | Should -BeLike $testLocation;
            $Bookmarks.Item($i - 1).description | Should -Be "Test File Location $i";
            $Bookmarks.Item($i - 1).Mode | Should -Be "-f-";
            $Bookmarks.Item($i - 1).Type | Should -Be File;
        }

        Context "with given file location" {
            $Script:Bookmarks.Clear();

            It "adds a bookmark to the bookmark list" {
                $testLocation = New-FileInTestDrive "Test File 1";
                New-Bookmark -location $testLocation -description "Test File Location 1";
        
                $checkFileBookmark.Invoke(1, "System.IO.FileInfo")
            }

            It "adds a second bookmark to the bookmark list" {
                $testLocation = New-FileInTestDrive "Test File 2";
                New-Bookmark -location $testLocation -description "Test File Location 2";

                $checkFileBookmark.Invoke(2, "System.IO.FileInfo")
            }

            It "adds a bookmark with file path given as String to the bookmark list" {
                $testLocation = New-FileInTestDrive "Test File 3";
                $testLocation = $testLocation.FullName;
                New-Bookmark -location $testLocation -description "Test File Location 3";

                $checkFileBookmark.Invoke(3, "String")
            }
        
            It "adds a bookmark with file path given as PathInfo to the bookmark list" {
                $testLocation = New-FileInTestDrive "Test File 4";
                $testLocation = Resolve-Path $testLocation;
                New-Bookmark $testLocation -description "Test File Location 4";
        
                $checkFileBookmark.Invoke(4, "System.Management.Automation.PathInfo")
            }
        }
        
        Context "without given location" {
            $Script:Bookmarks.Clear();

            It "adds a bookmark with the current path to the bookmark list" {
                $testLocation = New-FolderInTestDrive "Fifth Location Test Directory";
                Push-Location $testLocation;

                New-Bookmark "Fifth Test Location";

                $Bookmarks | Should -Not -BeNullOrEmpty;
                $Bookmarks.Count | Should -Be 1;

                $Bookmarks.Item(0).location | Should -BeLike $testLocation;
                $Bookmarks.Item(0).description | Should -Be "Fifth Test Location";
                $Bookmarks.Item(0).Mode | Should -Be "d--";
                $Bookmarks.Item(0).Type | Should -Be Directory;

                Pop-Location;
            }
        }

        Context "with non-existing path" {
            BeforeEach {
                $Bookmarks.Clear();
            }
            It "adds a bookmark of Type 'Unknown' for <pathType>-type path" -TestCases @(
                @{ pathType = "File"; pathLeaf = "Test File.txt" }
                @{ pathType = "Directory"; pathLeaf = "Test Folder"}
            ) {
                param($pathType, $pathLeaf)
                $testLocation = Join-Path $testDrive $pathLeaf;
                Test-Path $testLocation | Should -Be $false;
            
                New-Bookmark "Test $pathType Location" -Location $testLocation;

                $Bookmarks | Should -Not -BeNullOrEmpty;
                $Bookmarks.Count | Should -Be 1;
        
                $Bookmarks.Item(0).location | Should -BeLike $testLocation;
                $Bookmarks.Item(0).description | Should -Be "Test $pathType Location";
                $Bookmarks.Item(0).Mode | Should -Be "--u";
                $Bookmarks.Item(0).Type | Should -Be Unknown;
            }
        }

        Context "output" {
            It "does not return anything when bookmark is set" {
                $sixthLocation = New-FolderInTestDrive "Sixth Test Folder";

                New-Bookmark "Sixth Test Location" -location $sixthLocation | Should -BeNullOrEmpty;
            }
        }

        Context "Handling of erroneous bookmark declaration" {
            $Script:Bookmarks.Clear();

            $testLocationAlpha = New-FolderInTestDrive "Test Location Alpha";
            New-Bookmark "Alpha Location" $testLocationAlpha;
            
            $testLocationBeta = New-FolderInTestDrive "Test Location Beta";

            BeforeEach {
                (Get-Bookmark).Length | Should -Be 1;
            }

            AfterEach {
                (Get-Bookmark).Length | Should -Be 1;
                (Get-Bookmark).Description | Should -Be "Alpha Location";
            }

            It "throws an exception if empty description is given, and it does not add a bookmark" {
                {New-Bookmark -Description "" -Location $testLocationBeta} | Should -Throw;
            }

            It "throws an exception if `$null is given as description, and it does not add a bookmark" {
                {New-Bookmark -Description $null -Location $testLocationBeta} | Should -Throw;
            }

            It "throws an exception if folder path with invalid PSDrive root is given (CC:\), and it does not add a bookmark" {
                {New-Bookmark -Description "erroneous PSDrive root" -Location "CC:\"} | Should -Throw "Given location 'CC:\' is not a file system path";
            }

            It "throws an exception if file path with invalid PSDrive root is given (CC:\), and it does not add a bookmark" {
                {New-Bookmark -Description "erroneous PSDrive root" -Location "CC:\test.txt"} | Should -Throw "Given location 'CC:\test.txt' is not a file system path";
            }

            It "throws an exception if existing non-filesystem path (HKCU:\) is given as Location, and it does not add a bookmark" {
                {New-Bookmark -Description "erroneous PSDrive root" -Location "HKCU:\"} | Should -Throw "Given location 'HKCU:\' is not a file system path";
            } 
        }
    }
}