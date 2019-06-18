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

    Describe "Remove-Bookmark" {
        $folderAlpha = New-FolderInTestDrive "folderAlpha";
        $fileAlphaA = New-FileInTestDrive "fileAlphaA";

        BeforeEach {
            $Bookmarks.Clear();
        
            New-Bookmark -description "Alpha" -location $folderAlpha;    
            New-Bookmark -description "AlphaA" -location $fileAlphaA;
        }

        It "removes a bookmark with the given description" {
            (Get-Bookmark "AlphaA").Length | Should -Be 1;
    
            Remove-Bookmark "AlphaA";
    
            Get-Bookmark "AlphaA" | Should -BeNullOrEmpty;
        }

        It "does not remove a bookmark only with a matching description" {
            (Get-BookmarkExactDescription "Alpha").Length | Should -Be 1;

            Remove-Bookmark "AlphaA";

            (Get-BookmarkExactDescription "Alpha").Length | Should -Be 1;
            (Get-BookmarkExactDescription "Alpha").description | Should -BeExactly "Alpha";
            (Get-BookmarkExactDescription "Alpha").location | Should -BeLike $folderAlpha;
        }

        It "silently continues and does not delete anything if description is not equal to any bookmark" {
            (Get-Bookmark).Length | Should -Be 2;
            
            Remove-Bookmark "abc";

            (Get-Bookmark).Length | Should -Be 2;
        }

        It "removes the first bookmark occurrence if several bookmarks have the same description" {
            $folderAlphaTwo = New-FolderInTestDrive "folderAlphaTwo";
            New-Bookmark "Alpha" -location $folderAlphaTwo;

            (Get-BookmarkExactDescription "Alpha").Length | Should -Be 2;

            Remove-Bookmark "Alpha";

            (Get-BookmarkExactDescription "Alpha").Length | Should -Be 1;
            (Get-BookmarkExactDescription "Alpha").description | Should -Be "Alpha";
            (Get-BookmarkExactDescription "Alpha").location | Should -BeLike $folderAlphaTwo;
        }

        It "does not return anything when it is invoked" {
            Remove-Bookmark "Alpha" | Should -BeNullOrEmpty;
        }
    }
}