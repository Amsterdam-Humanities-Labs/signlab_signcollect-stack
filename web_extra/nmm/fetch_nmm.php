<?php
// Database configuration
include('../mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die(json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]));
}

// Validate and get input parameters
$id = isset($_GET['id']) ? $_GET['id'] : null;
$type = isset($_GET['type']) ? $_GET['type'] : null;
$gid = isset($_GET['gid']) ? $_GET['gid'] : null;
$thema = isset($_GET['thema']) ? $_GET['thema'] : null;

// Check if both id and type are provided


// Sanitize input to prevent SQL injection
$id = $id !== null ? $conn->real_escape_string($id) : null;
$type = $type !== null ? $conn->real_escape_string($type) : null;

if(isset($id))
{
// Query to fetch the video data based on id and type
$query = "SELECT * FROM nmm_data WHERE signbank_id = '$id' AND type = '$type' LIMIT 1";
$result = $conn->query($query);
}
elseif(isset($gid))
{
// Query to fetch the video data based on id and type
$query = "SELECT * FROM nmm_data WHERE id = '$gid' LIMIT 1";
$result = $conn->query($query);
}
elseif(isset($thema))
{
// Query to fetch the video data based on id and type
$query = "SELECT * FROM nmm_data WHERE thema LIKE '%$thema%'";
$result = $conn->query($query);
}




$response = [];

// Check if data is found
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    // Add video data to the response
    // echo $row['id'];

    $sqla = "SELECT videoTop, datetime_ms, user 
                 FROM CameraRecords 
                 WHERE zOg='nmm' AND glosId = ? AND (user LIKE ? OR ? = '%')";
        
        $stmt2 = $conn->prepare($sqla);
        
        // Define $userId as an empty string or adjust based on your actual requirements
        $userId = isset($_GET['userId']) ? $_GET['userId'] : '%';
        
        $videoTop = [];
        // Bind parameters correctly
        $stmt2->bind_param('iss', $row['id'], $userId, $userId);
        $stmt2->execute();
        $result2 = $stmt2->get_result();
        while ($row2 = $result2->fetch_assoc()) {
            $videoTop[] = $row2;
        }

        // Fetch all video records associated with the current glosid in matched_transcriptions
        $sqlb = "SELECT a_file, b_file, m_file, l_file, r_file FROM matched_transcriptions WHERE zOg='nmm' AND m_transcription = ? AND added = '1'";
        $stmt3 = $conn->prepare($sqlb);
        $stmt3->bind_param('s', $row['id']);
        $stmt3->execute();
        $result3 = $stmt3->get_result();


        $videos = [];
        while ($row3 = $result3->fetch_assoc()) {
            $videos[] = $row3;
        }
    $response = [
        'id' => $row['id'],
        'signbank_id' => $row['signbank_id'],
        'glos' => $row['glos'],
        'zelfopname' => $row['zelfopname'], // URL to the video
        'type' => $row['type'],
        'videos' => $videos,
        'nmm_id' => $row['id'],
        'videoTop' => $videoTop
    ];
}

if(isset($thema))
{
    $countQuery = "
    SELECT 
        COUNT(DISTINCT signbank_id) AS unique_signbank_count,
        SUM(CASE WHEN type = 'ready' THEN 1 ELSE 0 END) AS gc_count,
        SUM(CASE WHEN type = 'oc' THEN 1 ELSE 0 END) AS oc_count,
        SUM(CASE WHEN type = 'nmm' THEN 1 ELSE 0 END) AS nmm_count
    FROM nmm_data  WHERE thema LIKE '%$thema%'";
}
else
{
    $countQuery = "
    SELECT 
        COUNT(DISTINCT signbank_id) AS unique_signbank_count,
        SUM(CASE WHEN type = 'ready' THEN 1 ELSE 0 END) AS gc_count,
        SUM(CASE WHEN type = 'oc' THEN 1 ELSE 0 END) AS oc_count,
        SUM(CASE WHEN type = 'nmm' THEN 1 ELSE 0 END) AS nmm_count
    FROM nmm_data  WHERE thema NOT LIKE '%GEBARENSTRAND%' AND thema NOT LIKE '%GOMER%' AND thema NOT LIKE '%MOCAP%' AND thema NOT LIKE '%OLINE%'";
}
// Fetch counts of unique signbank_id and types


$countResult = $conn->query($countQuery);

if ($countResult && $countResult->num_rows > 0) {
    $countRow = $countResult->fetch_assoc();
    // Add the counts to the response
    $response['counts'] = [
        'unique_signbank_count' => $countRow['unique_signbank_count'],
        'gc_count' => $countRow['gc_count'],
        'oc_count' => $countRow['oc_count'],
        'nmm_count' => $countRow['nmm_count']
    ];
}

//we also want to know how much of rows in matched_transcription are added. 

//forloop through the nmm_data database, then look in matched_transcription based on m_transription and zOg = nmm then add to count and add to response
// Retrieve all records from nmm_data
if(isset($thema))
{
    $sql_nmm = "SELECT id FROM nmm_data  WHERE thema LIKE '%$thema%'";

}
else
{
    $sql_nmm = "SELECT id FROM nmm_data  WHERE thema NOT LIKE '%GEBARENSTRAND%' AND thema NOT LIKE '%GOMER%' AND thema NOT LIKE '%MOCAP%' AND thema NOT LIKE '%OLINE%'";

}
$result_nmm = $conn->query($sql_nmm);

$matchedCounts = [];
$totalCount = 0;

// Fetch all matched_transcriptions where zOg = 'nmm'
$sql_matched_all = "SELECT DISTINCT m_transcription FROM matched_transcriptions WHERE zOg = 'nmm'";
$result_matched_all = $conn->query($sql_matched_all);

$matchedTranscriptions = [];

if ($result_matched_all && $result_matched_all->num_rows > 0) {
    while ($row = $result_matched_all->fetch_assoc()) {
        $matchedTranscriptions[] = $row['m_transcription'];
    }
}

// Create a count map for m_transcription
$transcriptionCounts = array_count_values($matchedTranscriptions);

if ($result_nmm && $result_nmm->num_rows > 0) {
    while ($nmmRow = $result_nmm->fetch_assoc()) {
        $id = $nmmRow['id'];
        $count = isset($transcriptionCounts[$id]) ? $transcriptionCounts[$id] : 0;
        
        $matchedCounts[] = [
            'nmm_id' => $id,
            'matched_count' => $count
        ];
        $totalCount += $count;
    }
}

// Add counts to the response
// $response['counts']['matched_counts'] = $matchedCounts;
$response['counts']['total_matched_count'] = $totalCount;


//we want to count rows of form_data based on unique signbank value
// Retrieve all records from form_data
$sql_form = "SELECT *
FROM form_data
WHERE origin='UvA';
";
$result_form = $conn->query($sql_form);

$signbankCounts = [];
$totalSignbankCount = 0;

if ($result_form && $result_form->num_rows > 0) {
    while ($row = $result_form->fetch_assoc()) {
        $signbank = $row['signbank'];
        // For this example, we'll assume each unique signbank counts as 1
        $count = 1;
        $signbankCounts[] = [
            'signbank' => $signbank,
            'matched_count' => $count
        ];
        $totalSignbankCount += $count;
    }
}

// Add signbank counts to the response
$response['counts']['total_signbank_count'] = $totalSignbankCount;





// Return the combined response as JSON
echo json_encode($response);

// Close the database connection
$conn->close();
?>
