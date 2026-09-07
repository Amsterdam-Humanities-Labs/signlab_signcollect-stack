<?php
include('/web/mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);
//disable php warning
error_reporting(E_ERROR | E_PARSE);
//output errors in json format
header('Content-Type: application/json');
// Setting the custom error handler
// set_error_handler("jsonErrorHandler");

// Optionally, you can enable error reporting for all types of errors
// error_reporting(E_ALL);


// Check if the POST request is sent
    // Get the input values from the POST request
    // $createData = $_POST['createData'];

    if(isset($_POST['createData']))
    {
    $createData = $_POST['createData'];
    }
    else
    {
    //  $createData = '[{"id":"glosZoekInput","value":"twix"},{"id":"Handeness","value":""},{"id":"strongHand","value":""},{"id":"weakHand","value":""},{"id":"Location","value":""},{"id":"user","value":"1"}]';
    }
$decodedArray = json_decode($createData, true);
// print_r($decodedArray);
$resultArray = [];

// print_r($decodedArray);

// Iterate over the decoded array and extract the data
foreach ($decodedArray as $item) {
    // Use the 'id' as the key and 'value' as the value for your result array
    if (is_array($item['value']) || is_object($item['value'])) 
    {
        $resultArray[$item['id']] = json_encode($item['value']);
    }
    else
    {
    $resultArray[$item['id']] = $item['value'];
    }
}    
// print_r($resultArray);

    if ($resultArray['confirm'] !== "glosCreate" && $resultArray['glosZoekInput'] !== "") {

        $glos = $resultArray['glosZoekInput'];
        /// Assuming $glos is already defined and contains the base value.
        //trim the glos
        $glos = trim($glos);
        //chnage space to - 
        $glos = str_replace(' ', '-', $glos);
        

        $baseGlosMet = strtoupper($glos); // Make sure it's uppercase.


        //is if force for captures or for adding a new glos? 
        if($resultArray['addFor'] == "captures")
        {
            $responseGlos = $resultArray['glosZoekInput'];
            //this also means we have to add signbank ID, senses and phonology and set fonologie_fase1 to klaar


            
            $signbankJson = "glosses_transformed.json";
            $signbank = file_get_contents($signbankJson);

                    
            $decodedData = json_decode($signbank, true); // Decode as an associative array
            $matchedSenses = [];

            //NEDERLANDS

            foreach ($decodedData as $item) {
                foreach($item as $key => $details){
                        foreach($details as $senseKey => $senseValue){
                            if($senseKey == 'Annotation ID Gloss: Dutch'){
                                    if (strtolower($senseValue) == strtolower($baseGlosMet)) {
                                            $senses = [];
                                            $sensesEnglish = [];
                                            //forloop this object to strings $details['Senses: Dutch']
                                            foreach($details['Senses: Dutch'] as $skey => $svalue){
                                                $senses[] = $svalue;
                                            }
                                            foreach($details['Senses: English'] as $skey => $svalue){
                                                $sensesEnglish[] = $svalue;
                                            }



                                            $response = [
                                            'success' => true,
                                            'callback' => "glosAlreadyExist",
                                            'message' => $message,
                                            'glos' => $responseGlos,
                                            'senses' => $senses,
                                            'sensesEngels' => $sensesEnglish,
                                            'glosCallback' => $responseGlos,
                                            'studioOpnameWie' => $resultArray['studioOpnameWie'],
                                            'wie' => $resultArray['wie'], 
                                            'thema' => $resultArray['thema'],
                                            'wieNaam' => $resultArray['wieNaam'],
                                            'signbank' => $key,
                                            "fonologie_fase1" => "1",
                                            "fonologie_fase2" => "1",
                                            'glos' => $details['Annotation ID Gloss: Dutch'],
                                            'senses' => $senses,
                                            'glosZoekInput' => $details['Annotation ID Gloss: Dutch'],
                                            'Handeness' => $details['Handedness'],
                                            'strongHand' => $details['Strong Hand'],
                                            'weakHand' => $details['Weak Hand'],
                                            'HandshapeChange' => $details['Handshape Change'],
                                            'RelationArticulators' => $details['Relation Between Articulators'],
                                            'handLocation' => $details['Location'],
                                            'ContactType' => $details['Contact Type'],
                                            'MovementShape' => $details['Movement Shape'],
                                            'MovementDirection' => $details['Movement Direction'],
                                            'relativeOrienationMovement' => $details['Relative Orientation: Movement'],
                                            'relativeOrienationLocation' => $details['Relative Orientation: Location'],        
                                            'orientationChange' => $details['Orientation Change'],
                                            'RepeatedMovement' => $details['Repeated Movement'],
                                            'AlternatingMovement' => $details['Alternating Movement'],
                                            'virtualObjectt' => $details['Virtual Object'],
                                            'phonologyOther' => $details['Phonology Other'],
                                            'mouthGesture' => $details['Mouth Gesture'],
                                            'mouthing' => $details['Mouthing'],
                                            'phoneticVariation' => $details['Phonetic Variation'],
                                            'glosEngels' => $details['Annotation ID Gloss: English']
                                            ];
                                            break 3;
                                        }
                                        else
                                        {
                                            $response = [
                                                'success' => true,
                                                'callback' => "glosCreatedFailed",
                                                'message' => "Glos bestaat niet",
                                                'glos' => $responseGlos,
                                                'glosCallback' => $responseGlos,
                                                'wie' => $resultArray['wie'], 
                                                'thema' => $resultArray['thema'],
                                            ];
                                        }
                                
                                }
                            }
                        
                    }
                }

        }
        else
        {


        $glosList = Array();

        //first check if there is already suffix like -A in the glos
        //first check if there is already a suffix like -A in the glos at the end of the string
        //the suffix is always A till Z, so one letter maximum. 
        //if there is another else, then it is not a suffix.

        $baseGlos = preg_replace('/[-+][A-Z]$/', '', $baseGlosMet);
        $glosListAZ = [];
        $glosListAZ[] = $baseGlos;
        for ($i = 'A'; $i <= 'Z';) {
        $glosListAZ[] = $baseGlos . "-" . $i;
        if ($i == 'Z') 
        {
            break;
        }
        $i = chr(ord($i) + 1);
        }

        //loop through the array
        foreach($glosListAZ as $glos)
        {
            // Prepare and execute the query.
            $query = "SELECT * FROM form_data WHERE glos = ?";
            $stmt = $conn->prepare($query);
            $stmt->bind_param("s", $glos);
            $stmt->execute();
            $result = $stmt->get_result();
            //add result to list
            if($result->num_rows > 0)
            {
                $row = $result->fetch_assoc();
                $glosList[] = $glos;

            }


                    $signbankJson = "glosses_transformed.json";
                    $signbank = file_get_contents($signbankJson);
                    $decodedData = json_decode($signbank, true); // Decode as an associative array
                    $matchesGlos = [];
                    $matchesGlos[] = array_filter($decodedData, function ($entry) use ($glos) {
                        $details = current($entry);
                        $matchesGlos = empty($glos) || $details['Annotation ID Gloss: Dutch'] === $glos;

                        return $matchesGlos;
                    });
                    foreach ($matchesGlos as $key => $value) {
                        if (!empty($value)) {
                            $glosList[] = $glos;
                        }
                    }
          
            // Increment the letter. If 'Z' is reached, break the loop.
           
        }



        if (is_array($glosList) && count($glosList) > 0) {
            $glosList = array_unique($glosList);   
            $nextIdentifier = findNextFreeIdentifier($glosList);
            $message = "Glos bestaat al. Laatste letter toegevoegd. Aanmaken?";
            $messageCallback = "glosAlreadyExist";
        } else {
            $message = "Glos bestaat nog niet. Aanmaken?";
            $nextIdentifier = $baseGlos;
            $messageCallback = "glosDoesntExist";
        }


            // "glos" already exists, provide suggestion
            $senses = [];
            $senses[] = strtolower(str_replace('-', ' ', $baseGlos));
            

                $responseGlos = $nextIdentifier;

            

                $response = [
                    'success' => true,
                    'callback' => $messageCallback,
                    'message' => $message,
                    'glos' => $responseGlos,
                    'senses' => $senses,
                    'listExistingGlosses' => $glosList,
                    'glosCallback' => $responseGlos,
                    'studioOpnameWie' => $resultArray['studioOpnameWie'],
                    'wie' => $resultArray['wie'], 
                    'thema' => $resultArray['thema'],
                    'wieNaam' => $resultArray['wieNaam'],
                ];
            
            }
    }
    elseif($resultArray['confirm'] == "glosCreate")
    {
            // Create the glos in the database
            $glosCreated = true; // Replace this with your actual database query

            $glos = $resultArray['glosZoekInput'];
            $handeness = $resultArray['Handeness'];
            $strongHand = $resultArray['strongHand'];
            $weakHand = $resultArray['weakHand'];
            $handshapeChange = $resultArray['HandshapeChange'];
            $relationArticulators = $resultArray['RelationArticulators'];
            $location = $resultArray['handLocation'];
            $contactType = $resultArray['ContactType'];
            $movementShape = $resultArray['MovementShape'];
            $movementDirection = $resultArray['MovementDirection'];
            $repeatedMovement = $resultArray['RepeatedMovement'];
            $alternatingMovement = $resultArray['AlternatingMovement'];
            $user = $resultArray['user'];
            $zelfopname = $resultArray['zelfopname'];
            $wie_snel_opname = $resultArray['wie_snel_opname'];
            $studioOpnameWie = $resultArray['studioOpnameWie'];
            $thema = $resultArray['thema'];
            $senses = $resultArray['senses'];
            $wieNaam = $resultArray['wieNaam'];
            $wie = $resultArray['wie'];
            $signbank = $resultArray['signbank'];
            $wanneer = date("Y-m-d H:i:s");
            $relativeOrienationMovement = $resultArray['relativeOrienationMovement'];
            $relativeOrienationLocation = $resultArray['relativeOrienationLocation'];
            $orientationChange = $resultArray['orientationChange'];
            $virtualObjectt = $resultArray['virtualObjectt'];
            $phonologyOther = $resultArray['phonologyOther'];
            $mouthGesture = $resultArray['mouthGesture'];
            $mouthing = $resultArray['mouthing'];
            $phoneticVariation = $resultArray['phoneticVariation'];
            $sensesEngels = $resultArray['sensesEngels'];
            $fonologie_fase1 = $resultArray['fonologie_fase1'];
            $fonologie_fase2 = $resultArray['fonologie_fase2'];
            $glosEngels = $resultArray['glosEngels'];
            

            $logboek = "Glos toegevoegd door: ".$wieNaam;




            //create $zelfopname as an array and add $zelfopname
            if($zelfopname)
            {
                $zelfopnameArray = json_encode(array(strval($zelfopname)), true);
            }
            else
            {
                $zelfopnameArray = json_encode(array(), true);
            }

            //convert $user to array
            $userArray = json_encode(array(strval($user)), true);
            //convert $wie to array
            $wieArray = json_encode(array(strval($wie)), true);

            //prepare and execute the query
      $query = "INSERT INTO form_data (signbank, logboek,
    glos, handeness, strongHand, weakHand, handLocation, handshapeChange, relationArticulators,
    contactType, movementShape, movementDirection, repeatedMovement, alternatingMovement, wie, zelfopname, wie_snel_opname, studioOpnameWie, thema, senses, wanneer, 
    relativeOrienationMovement, relativeOrienationLocation, orientationChange, virtualObjectt, phonologyOther, mouthGesture, mouthing, phoneticVariation, sensesEngels,
    fonologie_fase1, fonologie_fase2, glos_engels, madeByWie
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

$stmt = $conn->prepare($query);

// Bind the parameters from the result array.
$stmt->bind_param(
    "ssssssssssssssssssssssssssssssssss",
    $signbank, $logboek, $glos, $handeness, $strongHand, $weakHand, $location, $handshapeChange, $relationArticulators,
    $contactType, $movementShape, $movementDirection, $repeatedMovement, $alternatingMovement, $wieArray, $zelfopnameArray, $wie_snel_opname, $studioOpnameWie, $thema, $senses, $wanneer, 
    $relativeOrienationMovement, $relativeOrienationLocation, $orientationChange, $virtualObjectt, $phonologyOther, $mouthGesture, $mouthing, $phoneticVariation, $sensesEngels,
    $fonologie_fase1, $fonologie_fase2, $glosEngels, $wie
);
        if ($stmt->execute()) {
            

                if($resultArray['oudeGlosID'])
                {
                    $oudeGlosID = $resultArray['oudeGlosID'];
                    //get the oudeGlosID from the database
                    $query = "SELECT * FROM form_data WHERE id = ?";
                    $stmt = $conn->prepare($query);
                    $stmt->bind_param("i", $oudeGlosID);
                    $stmt->execute();
                    $result = $stmt->get_result();
                    $row = $result->fetch_assoc();
                    $zelfopnameOld = $row['zelfopname'];
                    $zelfopnameOld = json_decode($zelfopnameOld, true);
                    //take the element equal to $zelfopname in array $zelfopname
                    if(($key = array_search($zelfopname, $zelfopnameOld)) !== false) {
                        unset($zelfopnameOld[$key]);
                    }

                    //then update the database with $zelfopnameold
                    $zelfopnameOldNew = json_encode($zelfopnameOld, true);

                    $query = "UPDATE form_data SET zelfopname = ? WHERE id = ?";
                    $stmt = $conn->prepare($query);
                    $stmt->bind_param("si", $zelfopnameOldNew, $oudeGlosID);
                    $stmt->execute();



                }

                $response = [
                    'success' => true,
                    'callback' => 'glosCreated',
                    'message' => 'Glos is aangemaakt.',
                    'old' => $zelfopnameOld,
                    'new' => $zelfopnameOldNew,
                    'zelfopname' => $zelfopname,
                    'id' => $conn->insert_id,
                    'glosCallback' => $glos,

                ];

            } else {
                $response = [
                    'success' => false,
                    'callback' => 'glosCreatedFailed',
                    'message' => "failed",
                    'glosCallback' => $glos,

                ];

            }
    } else {
        // No input values filled in
        $response = [
            'success' => false,
            'message' => 'Minimaal een veld moet ingevuld zijn.',
        ];
    }

    // Send the response back to JavaScript
    echo json_encode($response);



    function findNextFreeIdentifier($identifiers) {
        // print_r($identifiers);
        // Get the last identifier in the array
        $lastIdentifier = end($identifiers);
        
        $modifiedIdentifier = preg_replace('/[-+][A-Z]$/', '', $lastIdentifier);

        //is er meer dan 1 identifier en heeft het geen - suffix? dan return TWIX-B
        if(count($identifiers) >= 1 && $lastIdentifier == $modifiedIdentifier)
        {
            return $lastIdentifier . '-B';
        }
    
        //als TWIX-A is laatste identifier maar modified is TWIX dan is het TWIX-B
        if ($modifiedIdentifier !== $lastIdentifier) 
        {
    
            //calculate the next letter
            $ex = explode('-', $lastIdentifier);
            //get the last letter and increment it
            $lastLetter = end($ex);
            
            $nextLetter = chr(ord($lastLetter) + 1);
    
            // Return the next identifier
            return $modifiedIdentifier .'-'. $nextLetter;
        }
        else
        {
            //als TWIX is laatste identifier dan is het TWIX-A
            return $lastIdentifier . '-A';
        }
    }


function jsonErrorHandler($errno, $errstr, $errfile, $errline) {
    $errorData = [
        'error' => [
            'type' => $errno,
            'message' => $errstr,
            'file' => $errfile,
            'line' => $errline,
        ]
    ];

    // Setting the content type to application/json
    header('Content-Type: application/json');

    // Outputting the error data in JSON format
    echo json_encode($errorData);

    // Preventing the default PHP error handler from executing
    return true;
}