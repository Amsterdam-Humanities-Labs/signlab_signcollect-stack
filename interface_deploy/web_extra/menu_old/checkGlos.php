<?php
// Replace these variables with your actual database credentials
include('/web/mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);
// Set the JSON content type header
header('Content-Type: application/json');

//disable php warning
error_reporting(E_ERROR | E_PARSE);
// Check the connection
if ($conn->connect_error) {
    $output = [
        'glos' => '',
        'reason' => 'No MySQL connection'
    ];
    echo json_encode($output);
} else {
    // Retrieve $glos from $_GET and convert it to uppercase
    //Stap 1: Checken of glos al bestaat in de database en Signbank ECV (ook sense)
    $woordvorm = strtoupper($_GET['woordvorm']); //we zoeken eerst naar woordvorm

    //eerst kijken of woordvorm is opgegeven
    if($woordvorm == ""){
        $output = [
            'error' => true,
            'message' => 'Geen input opgegeven'
        ];
        echo json_encode($output);
        exit();
    }

    // Check if the glos already exists in the database
    $query = "SELECT * FROM form_data WHERE (glos LIKE ? OR senses LIKE ?) AND glosZichtbaar = 0";
    $stmt = $conn->prepare($query);
    $zoekTerm = "%{$woordvorm}%";
    $stmt->bind_param("ss", $zoekTerm, $zoekTerm); // 'ss' indicates both parameters are strings
    $stmt->execute();
    $result = $stmt->get_result();
    
    $foundArray = [];
    
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {


            //first check if it is processes
            if($row['processed'] == "2"){
                //then extract video from videoCenter
                $rowVideo = json_decode($row['videoCenter'], true);
                $video = $rowVideo[0]['file'];
                $video = str_replace('/web/', '', $video);
                $video = str_replace('/raw/', '/post/', $video);

            }
            else{
            //if not, does it have videoCenter?
                if($row['videoCenter'] != ""){
                    $rowVideo = json_decode($row['videoCenter'], true);
                    $video = $rowVideo[0]['file'];
                    $video = str_replace('/web/', '', $video);
                    $video = str_replace('studioFiles', 'studioFilesMini', $video);
                    //remove any date (2024-03-27) from the $video
                    $video = preg_replace('/\d{4}-\d{2}-\d{2}/', '', $video);

                }
                else
                {
                    $rowZelfopname  = json_decode($row['zelfopname'], true);
                    if(is_array($rowZelfopname) && count($rowZelfopname) >= 1)
                    {
                        $video = "uploads/".$rowZelfopname[0];
                    }
                    else
                    {
                        $video = "";
                    
                    }
                }

          
        }
        $output[] = [
            'glos' => $row['glos'],
            'sense' => $row['senses'],
            'source' => 'Signcollect',
            'video' => $video
        ];
    }
      
    }  
    else
    {
        $output = [];
    }
//ook zoeken naar senses/glosses bij Signbank ECV file


$signbankJson = "glosses_transformed.json";
$signbank = file_get_contents($signbankJson);

        
$decodedData = json_decode($signbank, true); // Decode as an associative array
$matchedSenses = [];

//NEDERLANDS

    foreach ($decodedData as $item) {
        foreach($item as $key => $details){
                foreach($details as $senseKey => $senseValue){
                    if($senseKey == 'Senses: Dutch'){
                        foreach($senseValue as $sense){
                            if (strpos(strtolower($sense), strtolower($woordvorm)) !== false) {
                                $senses = [];
                                $sensesEnglish = [];
                                //forloop this object to strings $details['Senses: Dutch']
                                foreach($details['Senses: Dutch'] as $skey => $svalue){
                                    $senses[] = $svalue;
                                }
                                foreach($details['Senses: English'] as $skey => $svalue){
                                    $sensesEnglish[] = $svalue;
                                }


                                $output[] = [
                                    'glos' => $details['Annotation ID Gloss: Dutch'],
                                    'glosEngels' => $details['Annotation ID Gloss: English'],
                                    'reason' => $senses,
                                    'source' => 'Signbank',
                                    'video' => $details['Video'],
                                    'glosID' => $key,
                                    'link' => $details['Link'],
                                    'webDic' => $details['In The Web Dictionary'],
                                     'senses' => $senses,
                                     'sensesEngels' => $sensesEnglish,
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
                                ];
                            }
                        }
                    }
                }
            
        }
    }



$glosID = [];

foreach ($decodedData as $item) {
    foreach($item as $key => $details){
            foreach($details as $senseKey => $senseValue){
                if($senseKey == 'Annotation ID Gloss: Dutch'){
                        if (strpos(strtolower($senseValue), strtolower($woordvorm)) !== false) {


                            $senses = [];
                            $sensesEnglish = [];
                            //forloop this object to strings $details['Senses: Dutch']
                            foreach($details['Senses: Dutch'] as $skey => $svalue){
                                $senses[] = $svalue;
                            }
                            foreach($details['Senses: English'] as $skey => $svalue){
                                $sensesEnglish[] = $svalue;
                            }


                            $output[] = [
                                'glos' => $details['Annotation ID Gloss: Dutch'],
                                'reason' => $details['Annotation ID Gloss: Dutch'],
                                'source' => 'Signbank',
                                'video' => $details['Video'],
                                'glosID' => $key,
                                'link' => $details['Link'],
                                'webDic' => $details['In The Web Dictionary'],
                                'senses' => $senses,
                                'sensesEngels' => $sensesEnglish,                               
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

                        
                            ];
                }
      
            }
        
    }
}



}


//ENGELS




foreach ($decodedData as $item) {
    foreach($item as $key => $details){
            foreach($details as $senseKey => $senseValue){
                if($senseKey == 'Senses: English'){
                    foreach($senseValue as $sense){
                        if (strpos(strtolower($sense), strtolower($woordvorm)) !== false) {
                            $senses = [];
                            $sensesEnglish = [];
                            //forloop this object to strings $details['Senses: Dutch']
                            foreach($details['Senses: Dutch'] as $skey => $svalue){
                                $senses[] = $svalue;
                            }
                            foreach($details['Senses: English'] as $skey => $svalue){
                                $sensesEnglish[] = $svalue;
                            }



                            $output[] = [
                                'glos' => $details['Annotation ID Gloss: Dutch'],
                                'reason' => $senses,
                                'source' => 'Signbank',
                                'video' => $details['Video'],
                                'glosID' => $key,
                                'link' => $details['Link'],
                                'webDic' => $details['In The Web Dictionary'],
                                'senses' => $senses,
                                'sensesEngels' => $sensesEnglish,
                                'glosZoekInput' => $details['Annotation ID Gloss: English'],
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
                            ];
                        }
                    }
                }
            }
        
    }
}




foreach ($decodedData as $item) {
foreach($item as $key => $details){
        foreach($details as $senseKey => $senseValue){
            if($senseKey == 'Annotation ID Gloss: English'){
                    if (strpos(strtolower($senseValue), strtolower($woordvorm)) !== false) {
                        $senses = [];
                        $sensesEnglish = [];
                        //forloop this object to strings $details['Senses: Dutch']
                        foreach($details['Senses: Dutch'] as $skey => $svalue){
                            $senses[] = $svalue;
                        }
                        foreach($details['Senses: English'] as $skey => $svalue){
                            $sensesEnglish[] = $svalue;
                        }


                        $output[] = [
                            'glos' => $details['Annotation ID Gloss: Dutch'],
                            'reason' => $details['Annotation ID Gloss: English'],
                            'source' => 'Signbank',
                            'video' => $details['Video'],
                            'glosID' => $key,
                            'link' => $details['Link'],
                            'webDic' => $details['In The Web Dictionary'],
                            'senses' => $senses,
                            'sensesEngels' => $sensesEnglish,
                            'glosZoekInput' => $details['Annotation ID Gloss: English'],
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

                    
                        ];
            }
  
        }
    
}
}



}



// filter out duplicates based on glos
$unique = [];
foreach ($output as $item) {
    $key = $item['glos'] . '_' . $item['source'];
    if (!in_array($key, $unique)) {
        $unique[] = $key;
        $filteredOutput[] = $item;
    }
}

// $filteredOutput = $output;
//first check if it is array or null
if (is_array($filteredOutput) && count($filteredOutput) > 0) {
//sort the array based on glos
usort($filteredOutput, function($a, $b) {
    return $a['glos'] <=> $b['glos'];
});} else {
    $filteredOutput = [];
    
}



echo json_encode($filteredOutput);
}
?>