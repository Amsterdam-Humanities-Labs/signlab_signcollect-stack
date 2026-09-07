<?php
// Enable error reporting for debugging (disable in production)
ini_set('display_errors', 0);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// Disable warnings and notices if needed
// error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);


$all = isset($_GET['all']) ? $_GET['all'] : 0;
$offset = isset($_GET['offset']) ? $_GET['offset'] : 0;
$limit = isset($_GET['limit']) ? $_GET['limit'] : 100;

// Database configuration
include('../mysql_config.php');

// Verify that necessary variables are set
if (!isset($servername, $username, $password, $database)) {
    die(json_encode(['error' => 'Database configuration variables are not set.']));
}

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    error_log('Database connection failed: ' . $conn->connect_error);
    die(json_encode(['error' => 'Internal server error.']));
}

// Function to fetch all rows from a table
function fetchAllRows($conn, $sql, $params = [], $types = '') {
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        error_log('Error preparing statement: ' . $conn->error);
        die(json_encode(['error' => 'Internal server error.']));
    }

    if ($params) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        error_log('Error executing statement: ' . $stmt->error);
        die(json_encode(['error' => 'Internal server error.']));
    }

    $result = $stmt->get_result();
    if (!$result) {
        error_log('Error getting result: ' . $stmt->error);
        die(json_encode(['error' => 'Internal server error.']));
    }

    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }

    $stmt->close();
    return $rows;
}

// Function to remove duplicates based on 'signbank' value
function removeDuplicatesBySignbank($array) {
    $uniqueSignbanks = [];
    $result = [];

    foreach ($array as $item) {
        if (!in_array($item['signbank'], $uniqueSignbanks)) {
            $uniqueSignbanks[] = $item['signbank'];
            $result[] = $item;
        }
    }

    return $result;
}

// Function to recursively sanitize data for JSON
function sanitize_for_json($data) {
    if (is_array($data)) {
        return array_map('sanitize_for_json', $data);
    } elseif (is_string($data)) {
        // Convert to UTF-8
        return mb_convert_encoding($data, 'UTF-8', 'UTF-8');
    } else {
        return $data;
    }
}

// 1. Fetch all matched_transcriptions with zOg='nmm'
$sql_matched_transcriptions = "SELECT DISTINCT m_transcription, m_file FROM matched_transcriptions WHERE zOg = 'nmm' AND added='1'";
$matchedTranscriptionRows = fetchAllRows($conn, $sql_matched_transcriptions);

// 1.b Fetch all matched_transcriptions with zOg='nmm' and thema='ALLES'


// Create an associative array for matched transcriptions for quick lookup
$matchedTranscriptions = [];
foreach ($matchedTranscriptionRows as $mtRow) {
    // Normalize to lowercase for case-insensitive matching
    $key = trim($mtRow['m_transcription']);
    $matchedTranscriptions[$key] = $mtRow['m_transcription'];
    $matchedVideos[$key] = $mtRow['m_file'];
}


// 2. Fetch all nmm_data where id matches m_transcription from matched_transcriptions
if (empty($matchedTranscriptions)) {
    die(json_encode(['error' => 'No matched_transcriptions found with zOg=\'nmm\'.']));
}

$ids = array_values($matchedTranscriptions);
$ids_placeholder = implode(',', array_fill(0, count($ids), '?'));
$sql_nmm_data = "SELECT DISTINCT id, signbank_id FROM nmm_data";
$stmt_nmm = $conn->prepare($sql_nmm_data);

if (!$stmt_nmm) {
    error_log('Error preparing nmm_data query: ' . $conn->error);
    die(json_encode(['error' => 'Internal server error.']));
}


if (!$stmt_nmm->execute()) {
    error_log('Error executing nmm_data query: ' . $stmt_nmm->error);
    die(json_encode(['error' => 'Internal server error.']));
}

$result_nmm = $stmt_nmm->get_result();
if (!$result_nmm) {
    error_log('Error getting nmm_data result: ' . $stmt_nmm->error);
    die(json_encode(['error' => 'Internal server error.']));
}

$nmmDataRows = [];
while ($row = $result_nmm->fetch_assoc()) {
    $nmmDataRows[] = $row;
}

$stmt_nmm->close();

// Check if nmmDataRows is empty
if (empty($nmmDataRows)) {
    die(json_encode(['error' => 'No records found in nmm_data matching matched_transcriptions.']));
}

// 3. Extract signbank_ids from nmm_data
$signbank_ids = array_map(function($item) {
    return $item['signbank_id'];
}, $nmmDataRows);

// Remove duplicates
$signbank_ids = array_unique($signbank_ids);

if (empty($signbank_ids)) {
    die(json_encode(['error' => 'No signbank_ids found in nmm_data.']));
}

$signbank_placeholder = implode(',', array_fill(0, count($signbank_ids), '?'));


$sql_form_data = "SELECT DISTINCT id, glos, signbank, thema FROM form_data WHERE id IN ($signbank_placeholder) AND glosZichtbaar = '0'";
$stmt_form = $conn->prepare($sql_form_data);

if (!$stmt_form) {
    error_log('Error preparing form_data query: ' . $conn->error);
    die(json_encode(['error' => 'Internal server error.']));
}

$types_form = str_repeat('s', count($signbank_ids));
$stmt_form->bind_param($types_form, ...$signbank_ids);

if (!$stmt_form->execute()) {
    error_log('Error executing form_data query: ' . $stmt_form->error);
    die(json_encode(['error' => 'Internal server error.']));
}

$result_form = $stmt_form->get_result();
if (!$result_form) {
    error_log('Error getting form_data result: ' . $stmt_form->error);
    die(json_encode(['error' => 'Internal server error.']));
}

$formDataRows = [];
while ($row = $result_form->fetch_assoc()) {
    $formDataRows[] = $row;
}

$stmt_form->close();

// 4. Fetch all form_data rows for unmatchedGloss
$sql_all_form_data = "SELECT DISTINCT id, glos, signbank, zelfopname, thema FROM form_data WHERE thema NOT LIKE '%GEBARENSTRAND%' AND thema NOT LIKE '%GOMER%' AND thema NOT LIKE '%MOCAP%' AND thema NOT LIKE '%OLINE%' AND glosZichtbaar = '0'";
$allFormDataRows = fetchAllRows($conn, $sql_all_form_data);

if (empty($allFormDataRows)) {
    die(json_encode(['error' => 'No records found in form_data.']));
}

// Create a map of form_data based on id
$formDataMap = [];
foreach ($allFormDataRows as $fdRow) {
    $formDataMap[$fdRow['id']] = $fdRow;
}

// Create a set of matched signbank_ids
$matchedSignbankIds = array_flip($signbank_ids);

// Initialize result arrays
$matchedGloss = [];
$unmatchedGloss = [];



// print_r($matchedVideos['1271']);
// Iterate through formDataRows and categorize
foreach ($formDataRows as $fdRow) {
    $videoslala = [];
    foreach ($nmmDataRows as $nmmRow) {
        if ($nmmRow['signbank_id'] == $fdRow['id']) {
            $nmmId = $nmmRow['id'];
            break;
        }
    }
    $id = trim($fdRow['id']);
    $glos = $fdRow['glos'];
    $signbank = $fdRow['signbank'];
    $thema = $fdRow['thema'];
    $nmmId = $nmmId;

    if (isset($matchedSignbankIds[$id])) {
        $videoslala[] = $matchedVideos[$nmmId];
        $matchedGloss[] = [
            'ID' => $id,
            'glos' => $glos,
            'signbank' => $signbank,
            'videos' => $videoslala,
            'thema' => $thema,
            'type' => "gc",
            'nmmId' => $nmmId
        ];
    }
}

// print_r($nmmDataRows);
// Determine unmatchedGloss by excluding matchedSignbankIds
foreach ($formDataMap as $fd_id => $fdRow) {
    if (!isset($matchedSignbankIds[$fd_id]) && !is_null($fdRow['signbank'])) {

        $nmmId = null;
        foreach ($nmmDataRows as $nmmRow) {
            if ($nmmRow['signbank_id'] === $fdRow['signbank']) {
                $nmmId = $nmmRow['id'];
                break;
            }
        }
            
        $unmatchedGloss[] = [
            'ID' => $fd_id,
            'glos' => $fdRow['glos'],
            'signbank' => $fdRow['signbank'],
            'zelfopname' => $fdRow['zelfopname'],
            'type' => "gc",
            'thema' => $fdRow['thema'],
            'nmmId' => $nmmId
        ];
    }
}

// Remove duplicates from matchedGloss and unmatchedGloss based on 'signbank'
$matchedGloss = removeDuplicatesBySignbank($matchedGloss);
$unmatchedGloss = removeDuplicatesBySignbank($unmatchedGloss);

// Re-index the arrays  
$matchedGloss = array_values($matchedGloss);
$unmatchedGloss = array_values($unmatchedGloss);

// 5. Fetch glos from CameraRecords
$sql_camera_records = "SELECT DISTINCT glosId FROM CameraRecords WHERE zOg = 'nmm' AND stateVideo = 'stopped'";
$cameraRecordsRows = fetchAllRows($conn, $sql_camera_records);

// Create a set of glos from CameraRecords for quick lookup
$cameraRecordsGlos = [];
foreach ($cameraRecordsRows as $crRow) {
    $glosId = $crRow['glosId'];
    $cameraRecordsGlos[] = $glosId;
}
//get all 

// 6. Filter unmatchedGloss by removing entries with glos present in CameraRecords
$filteredUnmatchedGloss = [];
foreach ($unmatchedGloss as $item) {
    $nmmId = $item['nmmId'];
    $mt_id = $matchedTranscriptions[$item['nmmId']];
    $glos = $item['glos'];

    ///kijken of glos al in mt bestaat
    //AANRAAKSCHERM-D komt voor in form_data, dus dat komt hier voorbij

    //daarna kijken we in matched_transcriptions of het er voorkomt
    //daarna in CameraRecords

    //als het in minimaal een van beide voorkomt, dan moet het niet in unmatchedGloss komen

    if($mt_id)
    {
        continue;
    }
    if(in_array($glos, $cameraRecordsGlos))
    {
        continue;
    }
    $filteredUnmatchedGloss[] = $item;

  
}

//we kijken van nmm_data of 

$unmatchedGloss = $filteredUnmatchedGloss;

// Remove duplicates again after filtering
$unmatchedGloss = removeDuplicatesBySignbank($unmatchedGloss);

// Re-index the arrays
$matchedGloss = array_values($matchedGloss);
$unmatchedGloss = array_values($unmatchedGloss);
shuffle($unmatchedGloss);


// Filter out rows with thema equal to 'GEBARENSTRAND' or starting with '_'
$filteredMatchedGloss = array_filter($matchedGloss, function($item) {

    if(strpos($item['thema'], 'STRAND') == false)
    {
        if(strpos($item['thema'], 'MOCAP') == false)
        {
            if(strpos($item['thema'], 'OLINE') == false)
            {
                
            return true;
        }
        else
        {
            return false;
        }

    }
}
});

$filteredUnmatchedGloss = array_filter($unmatchedGloss, function($item) {
    if(strpos(strtoupper($item['thema']), 'STRAND') == false)
    {
        if(strpos(strtoupper($item['thema']), 'MOCAP') == false)
        {
            if(strpos(strtoupper($item['thema']), 'OLINE') == false)
            {
                if(strpos(strtoupper($item['thema']), 'GOMER') == false)
                {
                
            return true;
        }
        else
        {
            return false;
        }

    }
}}});


$response['matchedGloss'] = array_values($filteredMatchedGloss);
$response['unmatchedGloss'] = array_values($filteredUnmatchedGloss);
// Prepare the response with counts
$response = [
    'success' => true,
    'matchedCount' => count($filteredMatchedGloss),
    'unmatchedCount' => count($filteredUnmatchedGloss),
    // 'matchedGloss' => $matchedGloss,
    'unmatchedGloss' => array_slice($filteredUnmatchedGloss, 0, 1)


];

if ($all) {
    $response['matchedGloss'] = array_slice($matchedGloss, $offset, $limit);
    $response['unmatchedGloss'] = array_slice($unmatchedGloss, $offset, $limit);
}
// Randomize the unmatchedGloss array

// Sanitize the $response array
$response = sanitize_for_json($response);

// Attempt to encode to JSON
//add [] to the json response
// $jsonResponse = "[" . $jsonResponse . "]";

//we are going to get gloss from $response['unmatchedGloss'][0]['glos'] and then check if such glos alrady exist in nmm_data, otherwise we will add it to nmm_data
$query = "SELECT * FROM nmm_data WHERE glos = ? AND (type = 'gc' OR type = 'ready')";
$stmt = $conn->prepare($query);
$stmt->bind_param('s', $response['unmatchedGloss'][0]['glos']);
$stmt->execute();
$result = $stmt->get_result();
if ($result->num_rows === 0) {
    $query = "INSERT INTO nmm_data (glos, signbank_id, type, thema) VALUES (?, ?, ?, ?)";
    $stmt = $conn->prepare($query);
    $glos = $response['unmatchedGloss'][0]['glos'];
    $signbank = $response['unmatchedGloss'][0]['signbank'];
    $type = "ready";
    $thema = "ALLES";
    $stmt->bind_param('ssss', $glos, $signbank, $type, $thema);
    $stmt->execute();
    //then we get the id of the inserted row
    $id = $stmt->insert_id;
    $response['unmatchedGloss'][0]['ID'] = $id;

    $stmt->close();
    //then we update response with the id
}
else
{
    //we get id from the result
    $row = $result->fetch_assoc();
    $id = $row['id'];
    $response['unmatchedGloss'][0]['ID'] = $id;
}

$jsonResponse = json_encode($response);

// Check for JSON encoding errors
if ($jsonResponse === false) {
    // Fetch the last JSON error
    $jsonError = json_last_error_msg();
    echo json_encode(['error' => "JSON Encoding Error: " . $jsonError]);
} else {
    // Set the Content-Type header to application/json
    header('Content-Type: application/json');
    echo $jsonResponse;
}




// Close the database connection
$conn->close();
?>