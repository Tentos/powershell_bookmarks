if (Test-Path Variable:\old_prompt) {
    Set-Content -Path "Function:\prompt" -Value $global:old_prompt;
}
Remove-Module Bookmarks -ErrorAction SilentlyContinue;
Import-Module .\Bookmarks.psm1 -Force

InModuleScope Bookmarks {
    function New-FolderInTestDrive([string] $folderName) {
        return New-Item -ItemType Directory -Path TestDrive: -Name $folderName;
    }
    
    function New-FileInTestDrive([string] $fileName) {
        return New-Item -ItemType File -Path TestDrive: -Name "${fileName}.txt";
    }

    Describe "Bookmark Import and Export" {
        $existingFolderAlpha = New-FolderInTestDrive "folderAlpha";
        $existingFileAlphaA = New-FileInTestDrive "fileAlphaA";
        $folderBeta = New-FolderInTestDrive "folderBeta";        
        $nonExistingFolderGamma = Join-Path $testDrive "folderGamma"
        $nonExistingFileGammaG = Join-Path $testDrive "fileGammaG.txt"
        
        $exportFolderPath = Join-Path TestDrive: "PSBookmarks";
        Mock -CommandName Get-ExportBookmarksFolder {return $exportFolderPath}
        $bookmarkFilePath = Join-Path $exportFolderPath "psbookmarks.xml";        
        
        BeforeEach {
            $Bookmarks.Clear();
            New-Bookmark -description "Alpha" -location $existingFolderAlpha;    
            New-Bookmark -description "AlphaA" -location $existingFileAlphaA;
            New-Bookmark -description "Gamma" -location $nonExistingFolderGamma;    
            New-Bookmark -description "GammaG" -location $nonExistingFileGammaG;
        }

        Context "Bookmark export folder exists" {
            New-FolderInTestDrive "PSBookmarks";
            Mock -CommandName New-Item {};

            BeforeEach {
                Export-Bookmarks;
            }

            It "does not try to create the export folder" {
                Assert-MockCalled -CommandName New-Item -Times 0;
            }

            It "exports the bookmarks to the standard file" {
                Test-Path $bookmarkFilePath | Should -Be $true
            }

            It "successfully imports the bookmarks from the standard file" {
                Remove-Bookmark "Alpha";
                Remove-Bookmark "AlphaA";
                Remove-Bookmark "Gamma";
                Remove-Bookmark "GammaG";
                Get-Bookmark | Should -BeNullOrEmpty;
                
                Import-Bookmarks;

                $importedBookmarks = Get-Bookmark;

                $importedBookmarks.Length | Should -Be 4;

                $importedBookmarks.Item(0) -is [Bookmark] | Should -Be $true;
                $importedBookmarks.Item(1) -is [Bookmark] | Should -Be $true;
                $importedBookmarks.Item(2) -is [Bookmark] | Should -Be $true;
                $importedBookmarks.Item(3) -is [Bookmark] | Should -Be $true;
                
                $importedBookmarks.Item(0).description | Should -BeExactly "Alpha";
                $importedBookmarks.Item(1).description | Should -BeExactly "AlphaA";
                $importedBookmarks.Item(2).description | Should -BeExactly "Gamma";
                $importedBookmarks.Item(3).description | Should -BeExactly "GammaG";
                
                $importedBookmarks.Item(0).location | Should -BeLike $existingFolderAlpha;
                $importedBookmarks.Item(1).location | Should -BeLike $existingFileAlphaA;
                $importedBookmarks.Item(2).location | Should -BeLike $nonExistingFolderGamma;
                $importedBookmarks.Item(3).location | Should -BeLike $nonExistingFileGammaG;

                $importedBookmarks.Item(0).Mode | Should -Be "d--"
                $importedBookmarks.Item(1).Mode | Should -Be "-f-"
                $importedBookmarks.Item(2).Mode | Should -Be "--u"
                $importedBookmarks.Item(3).Mode | Should -Be "--u"

                $importedBookmarks.Item(0).Type | Should -Be Directory
                $importedBookmarks.Item(1).Type | Should -Be File
                $importedBookmarks.Item(2).Type | Should -Be Unknown
                $importedBookmarks.Item(3).Type | Should -Be Unknown
            }

            It "deletes all bookmarks before the import from the standard file" {
                New-Bookmark "Beta" -location $folderBeta;
                (Get-Bookmark).Length | Should -Be 5;
                Get-Bookmark "Beta" | Should -Not -BeNullOrEmpty;

                Import-Bookmarks;

                (Get-Bookmark).Length | Should -Be 4;
                Get-Bookmark "Beta" | Should -BeNullOrEmpty; 
            }

            It "throws an exception if the standard file cannot be found" {
                Remove-Item $bookmarkFilePath;

                {Import-Bookmarks} | Should -Throw "The file '$bookmarkFilePath' with exported bookmarks does not exist. Please export bookmarks before importing.";
            }
        }

        Context "Bookmark export folder does not exist" {
            It "creates the export folder" {
                Test-Path $exportFolderPath | Should -Be $false;

                Export-Bookmarks

                Test-Path $exportFolderPath | Should -Be $true;
            }
        }
    }
}