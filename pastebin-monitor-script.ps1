# Start with defaults
$keywordsFile = 'keywords.txt'
$outputPath= '.'
$checkIP = $True

$check_index = 0
$check_list = @("") * 1000

while($True){
    Write-Host "Starting a loop"
	
	# Load the keywords
    $keywords = Get-Content $keywordsFile
    Write-Host "Loaded keywords:"
    $keywords| Foreach-Object{ Write-Host $_ }

    # get the jsons from the scraping api
    $response = Invoke-WebRequest "https://scrape.pastebin.com/api_scraping.php?limit=100"

    if($checkIP){
        if ($response.Content -like "*DOES NOT HAVE ACCESS*"){
           Write-Host "The IP of the machine running the script does not have access, go to pastebin and whitelist it then try again"
           break
        }
    }

    # if it was successful parse
    if($response.StatusCode -eq 200){

        # get json from the response
        $parsedJson = ConvertFrom-Json $response.Content

        # loop through the entries
        $parsedJson| ForEach-Object {
            $parsedJsonIndividual = $_
            # Now get the actual pastes if it is not in the last 1000 check_list
            if(-not $check_list.Contains($parsedJsonIndividual.key)){
                Write-Host "Checking $($parsedJsonIndividual.key)"
                $paste = Invoke-WebRequest $parsedJsonIndividual.scrape_url
                if($paste.StatusCode -eq 200){
                    $text = $paste.Content                   
                    # loop through the keywords to see if they are in the post
                    foreach($word in $keywords){
                        if($text.ToLower() -like "*$($word.ToLower())*"){ #TODO, add regex support here
                            Write-Host "Matched keyword $word and will save $($parsedJsonIndividual.key)"
                            
                            # Check whether the directory with the name of the keyword exists and create it if not
                            if(-not (Test-Path "$outputPath/$word")){
                                # Create the directory
                                New-Item -ItemType Directory -Force -Path "$outputPath/$word"
                            }
                            $text| Out-File "$outputPath/$word/$($parsedJsonIndividual.key).txt"


                        }
                    }
                }
                

                # Add to the checklist of the last 1000 so we don't fetch unnecessarily
                if($check_index -eq 999){
                    Write-Host "Reseting the checklist counter"
                    $check_index = 0
                }
                # Add the key to the last 1000 check_list and increment the counter
                $check_list[$check_index] = $parsedJsonIndividual.key
                $check_index += 1
            }
            else{
                Write-Host "Skipping $($parsedJsonIndividual.key), already processed"
            }
        }
    }
    else{
        Write-Host "There was an error calling the url"
    }
    Write-Host "Sleeping a minute"
    Start-Sleep 60
}

