<?php
include('../mysql_config.php');

// Connect to the database
$mysqli = new mysqli($servername, $username, $password, $database);
if ($mysqli->connect_errno) {
    echo "Failed to connect to MySQL: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
    exit();
}

// Retrieve 'glos' from CameraRecords where stateVideo is 'stopped' and zOg is 'nmm_oc'
$query_cr = "SELECT DISTINCT glos FROM CameraRecords WHERE stateVideo = 'stopped' AND zOg = 'nmm_oc'";
$result_cr = $mysqli->query($query_cr);

if (!$result_cr) {
    echo "Error fetching CameraRecords: " . $mysqli->error;
    exit();
}

$glosses_cr = [];
while ($row = $result_cr->fetch_assoc()) {
    
    //split $glos with space and take the first word
    $glos = explode(" ", $row['glos'])[0];
    //remove all whitespace
    $glos = preg_replace('/\s+/', '', $glos);
    $glosses_cr[] = $glos;
}

//retrieve all records from matched_transcription where zOg = 'nmm_oc'

$query_mt = "SELECT * FROM matched_transcriptions WHERE zOg = 'nmm_oc' AND added = '1'";
$result_mt = $mysqli->query($query_mt);

if (!$result_mt) {
    echo "Error fetching matched_transcriptions: " . $mysqli->error;
    exit();
}


$glosses_mt = [];
while ($row = $result_mt->fetch_assoc()) {
    $glos = $row['m_transcription'];
    $glosses_mt[$row['m_transcription']] = $glos;
}

// print_r($glosses_mt);


// Retrieve all records from nmm_data where zOg is 'oc'
$query_nmm = "SELECT * FROM nmm_data WHERE type = 'oc' AND zelfopname != ''";
$result_nmm = $mysqli->query($query_nmm);

if (!$result_nmm) {
    echo "Error fetching nmm_data: " . $mysqli->error;
    exit();
}

$nmm_data = $result_nmm->fetch_all(MYSQLI_ASSOC);

// Initialize output arrays
$output = [];
$output_mg = [];

// print_r($glosses_cr);
// Iterate through each record in nmm_data
foreach ($nmm_data as $nmm) {
    $glos = $nmm['glos'];
    $glosId = $nmm['id'];
    // echo $glos;
    


    if (!in_array($glos, $glosses_cr)) {
    

        // 'glos' not found in glosses_cr, add to unmatchedGloss (output)
        $output[] = [
            'id'          => $nmm['id'],
            'signbank'    => $nmm['signbank_id'],
            'type'        => $nmm['type'],
            'nmmId'       => $nmm['id'],
            'glos'        => $nmm['glos'],
            'thema'       => "ALLES",
            'zelfopname' => [$nmm['zelfopname']]
        ];
    } else {
        //then check in glosses_mt if glos is present,
        // if($glos == "STINKEN-C") {
        //     echo $glosses_mt[$glosId];
        //     echo $glos;
        // }

        if (array_key_exists($glosId, $glosses_mt) && $glosId == $glosses_mt[$glosId])
        {
        
            $output_mg[] = [
                'id'         => $nmm['id'],
                'signbank'   => $nmm['signbank_id'],
                'type'       => $nmm['type'],
                'nmmId'      => $nmm['id'],
                'glos'       => $nmm['glos'],
                'thema'      => "ALLES"
            ];
        }
        else
        {
             // 'glos' found in glosses_cr, add to matchedGlosses (output_mg)
             $output[] = [
                'id'          => $nmm['id'],
                'signbank'    => $nmm['signbank_id'],
                'type'        => $nmm['type'],
                'nmmId'       => $nmm['id'],
                'glos'        => $nmm['glos'],
                'thema'       => "ALLES",
                'zelfopname' => [$nmm['zelfopname']]
            ];
        }

       
    }
}

// Count the number of matched and unmatched glosses
$matchedCount   = count($output_mg);
$unmatchedCount = count($output);

// Prepare the JSON response
$response = [
    'unmatchedGloss'  => $output,
    'matchedGlosses'  => $output_mg,
    'matchedCount'    => $matchedCount,
    'unmatchedCount'  => $unmatchedCount
];

// Output the JSON
header('Content-Type: application/json');
echo json_encode($response);

// Close the database connection
$mysqli->close();
?>
