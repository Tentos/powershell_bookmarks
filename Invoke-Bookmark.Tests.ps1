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

    Describe "Invoke-Bookmark" {
        Mock -CommandName Invoke-Item -MockWith {};

        BeforeEach {
            Push-Location $(Get-Location) -StackName UnitTesting;
        }
    
        AfterEach {
            Pop-Location -StackName UnitTesting;
        }

        Context "for folders" {
            $Bookmarks.Clear()
    
            $folderAlpha = New-FolderInTestDrive "folderAlpha";
            $folderAlphaA = New-FolderInTestDrive "folderAlphaA";
            $folderBeta = New-FolderInTestDrive "folderBeta";
            $folderGamma = New-FolderInTestDrive "folderGamma";
    
            New-Bookmark -description "Alpha" -location $folderAlpha;    
            New-Bookmark -description "AlphaA" -location $folderAlphaA;
            New-Bookmark -description "Beta" -location $folderBeta;    
            New-Bookmark -description "Gamma" -location $folderGamma;
    
            
            It "if given description is equal to one existing description, it goes to this bookmark" {
                Invoke-Bookmark -descriptionLike "AlphaA";
                Get-Location | Should -BeLike $folderAlphaA;
            }
            
            It "if given description is unambiguously part of one bookmark description, it goes to this bookmark" {
                Invoke-Bookmark -descriptionLike "Bet";
                Get-Location | Should -BeLike $folderBeta;
            }
            
            It "if given description is ambiguously part of several descriptions, it goes to the bookmark whose description exactly matches" {
                Invoke-Bookmark -descriptionLike "Alpha";
                Get-Location | Should -BeLike $folderAlpha;
            }
    
            It "throws an exception if given description matches several bookmark descriptions and there is no exact match" {
                {Invoke-Bookmark -descriptionLike "Alph"} | Should -Throw "Description 'Alph' is ambiguous. Possible matching bookmarks: Alpha AlphaA";
            }
    
            It "throws an exception if given description does not match any description" {
                {Invoke-Bookmark -descriptionLike "x"} | Should -Throw "No matching bookmark found for description 'x'";
            }
    
            It "throws an exception if the bookmark location does not exist" {
                $nonExistingFolderPath = Join-Path $testDrive "nonExistingFolder";
                Test-Path $nonExistingFolderPath | Should -Be $false;
    
                New-Bookmark "nonExisting" -Location $nonExistingFolderPath;
                (Get-BookmarkExactDescription "nonExisting").Length | Should -Be 1;
    
                {Invoke-Bookmark -DescriptionLike "nonExisting"} | Should -Throw "Location '$nonExistingFolderPath' of bookmark does not exist";
            }
        }

        Context "for files" {
            $Bookmarks.Clear()
    
            $fileAlpha = New-FileInTestDrive "fileAlpha";
            $fileAlphaA = New-FileInTestDrive "fileAlphaA";
            $fileBeta = New-FileInTestDrive "fileBeta";
            $fileGamma = New-FileInTestDrive "fileGamma";
    
            New-Bookmark -description "Alpha" -location $fileAlpha;    
            New-Bookmark -description "AlphaA" -location $fileAlphaA;
            New-Bookmark -description "Beta" -location $fileBeta;    
            New-Bookmark -description "Gamma" -location $fileGamma;
            
            It "if given description is equal to one existing description, it invokes the file" {
                Invoke-Bookmark -descriptionLike "AlphaA";
                Assert-MockCalled -CommandName Invoke-Item -Times 1 -ParameterFilter {$Path -eq "$fileAlphaA"};
            }
            
            It "if given description is unambiguously part of one bookmark description, it invokes the file" {
                Invoke-Bookmark -descriptionLike "Bet";
                Assert-MockCalled -CommandName Invoke-Item -Times 1 -ParameterFilter {$Path -eq "$fileBeta"};
            }
            
            It "if given description is ambiguously part of several descriptions, it invokes the file whose bookmark description exactly matches" {
                Invoke-Bookmark -descriptionLike "Alpha";
                Assert-MockCalled -CommandName Invoke-Item -Times 1 -ParameterFilter {$Path -eq "$fileAlphaA"};
            }
    
            It "throws an exception if given description matches several bookmark descriptions and there is no exact match" {
                {Invoke-Bookmark -descriptionLike "Alph"} | Should -Throw "Description 'Alph' is ambiguous. Possible matching bookmarks: Alpha AlphaA";
            }
    
            It "throws an exception if given description does not match any description" {
                {Invoke-Bookmark -descriptionLike "x"} | Should -Throw "No matching bookmark found for description 'x'";
            }
    
            It "throws an exception if the bookmark file location does not exist" {
                $nonExistingFilePath = Join-Path $testDrive "nonExistingFile.txt";
                Test-Path $nonExistingFilePath | Should -Be $false;
    
                New-Bookmark "nonExisting" -Location $nonExistingFilePath;
                (Get-BookmarkExactDescription "nonExisting").Length | Should -Be 1;
    
                {Invoke-Bookmark -DescriptionLike "nonExisting"} | Should -Throw "Location '$nonExistingFilePath' of bookmark does not exist";
            }
        }

        Context "for bookmarks of type 'Unknown'" {
            $Bookmarks.Clear();

            $pathAlpha = Join-Path $testDrive "pathAlpha";
            Test-Path $pathAlpha | Should -Be $false;            
            $pathAlphaA = Join-Path $testDrive "pathAlphaA";
            Test-Path $pathAlphaA | Should -Be $false;
            $pathBeta = Join-Path $testDrive "pathBeta.txt";
            Test-Path $pathBeta | Should -Be $false;            
            $pathGamma = Join-Path $testDrive "pathGamma";
            Test-Path $pathGamma | Should -Be $false;

            New-Bookmark -description "Alpha" -location $pathAlpha;    
            New-Bookmark -description "AlphaA" -location $pathAlphaA;
            New-Bookmark -description "Beta" -location $pathBeta;    
            New-Bookmark -description "Gamma" -location $pathGamma;

            It "throws expected Exception if given description <caseDescription>" -TestCases @(
                @{ caseDescription = "is equal to one existing description"; givenDescription = "AlphaA"; expectedExceptionMessage = "Location '$pathAlphaA' of bookmark does not exist"}
                @{ caseDescription = "is unambiguously part of a bookmark description"; givenDescription = "Bet"; expectedExceptionMessage = "Location '$pathBeta' of bookmark does not exist"}
                @{ caseDescription = "is ambiguously part of several descriptions, but exactly matches one bookmark"; givenDescription = "Alpha"; expectedExceptionMessage = "Location '$pathAlpha' of bookmark does not exist"}
                @{ caseDescription = "matches several bookmark descriptions and there is no exact match"; givenDescription = "Alph"; expectedExceptionMessage = "Description 'Alph' is ambiguous. Possible matching bookmarks: Alpha AlphaA"}
                @{ caseDescription = "does not match any description"; givenDescription = "x"; expectedExceptionMessage = "No matching bookmark found for description 'x'"}
            ){
                param($givenDescription, $expectedExceptionMessage)                
                {Invoke-Bookmark -DescriptionLike $givenDescription} | Should -Throw $expectedExceptionMessage;
            }

            It "invokes the bookmark if file path has become valid" {
                New-FileInTestDrive "pathBeta";
                Test-Path $pathBeta | Should -Be $true;

                Invoke-Bookmark -DescriptionLike "Beta";
                Assert-MockCalled -CommandName Invoke-Item -ParameterFilter {$path -eq $pathBeta} -Times 1;
            }

            It "invokes the bookmark if folder path has become valid" {
                New-FolderInTestDrive "pathAlphaA";
                Test-Path $pathAlphaA | Should -Be $true;

                Invoke-Bookmark -DescriptionLike "AlphaA";
                Get-Location | Should -BeLike $pathAlphaA;
            }
        }
    }
}