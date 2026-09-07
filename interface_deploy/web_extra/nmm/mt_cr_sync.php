<?php
// Database configuration
include('../mysql_config.php');

// Set the Content-Type to application/json
header('Content-Type: application/json');

// Allow CORS (optional, adjust as needed)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Verify that necessary variables are set
if (!isset($servername, $username, $password, $database)) {
    http_response_code(500);
    echo json_encode(['error' => 'Database configuration variables are not set.']);
    exit;
}

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]);
    exit;
}

// Step 1: Fetch all m_transcription IDs where zOg = 'nmm' and added != 1
$sql_included = "
    SELECT m_transcription, DATE(`date`) as mt_date
    FROM matched_transcriptions
    WHERE zOg = 'nmm' AND added != 1
";

$result_included = $conn->query($sql_included);

if (!$result_included) {
    http_response_code(500);
    echo json_encode(['error' => 'Query failed (included): ' . $conn->error]);
    $conn->close();
    exit;
}

$included_glos = [];

while ($row = $result_included->fetch_assoc()) {
    $glosId = $row['m_transcription'];
    $date = $row['mt_date'];
    // Initialize the array if not already
    if (!isset($included_glos[$glosId])) {
        $included_glos[$glosId] = [];
    }
    // Store all dates associated with this glosId
    $included_glos[$glosId][] = $date;
}

$result_included->free();

// If no glosIds found, return empty data
if (empty($included_glos)) {
    echo json_encode(['data' => []]);
    $conn->close();
    exit;
}

// Step 2: Fetch all m_transcription IDs that have at least one entry with zOg = 'nmm' and added = 1
$sql_excluded = "
    SELECT DISTINCT m_transcription
    FROM matched_transcriptions
    WHERE zOg = 'nmm' AND added = 1
";

$result_excluded = $conn->query($sql_excluded);

if (!$result_excluded) {
    http_response_code(500);
    echo json_encode(['error' => 'Query failed (excluded): ' . $conn->error]);
    $conn->close();
    exit;
}

$excluded_glos = [];

while ($row = $result_excluded->fetch_assoc()) {
    $excluded_glos[] = $row['m_transcription'];
}

$result_excluded->free();

// Step 3: Exclude the glosIds that are in the excluded list
foreach ($excluded_glos as $excluded_glosId) {
    unset($included_glos[$excluded_glosId]);
}

// If no glosIds left after exclusion, return empty data
if (empty($included_glos)) {
    echo json_encode(['data' => []]);
    $conn->close();
    exit;
}

// Prepare a list of glosIds and their corresponding dates
$filtered_glosIds = array_keys($included_glos);

// Step 4: Fetch CameraRecords where glosId is in the filtered list and zOg = 'nmm'
$placeholders = implode(',', array_fill(0, count($filtered_glosIds), '?'));
$sql_camera = "
    SELECT *
    FROM CameraRecords
    WHERE zOg = 'nmm' AND glosId IN ($placeholders)
";

$stmt_camera = $conn->prepare($sql_camera);

if (!$stmt_camera) {
    http_response_code(500);
    echo json_encode(['error' => 'Prepare failed (camera): ' . $conn->error]);
    $conn->close();
    exit;
}

// Bind parameters dynamically
$types = str_repeat('s', count($filtered_glosIds)); // Assuming glosId is a string
$stmt_camera->bind_param($types, ...$filtered_glosIds);

// Execute the statement
if (!$stmt_camera->execute()) {
    http_response_code(500);
    echo json_encode(['error' => 'Execution failed (camera): ' . $stmt_camera->error]);
    $stmt_camera->close();
    $conn->close();
    exit;
}

// Get the result
$result_camera = $stmt_camera->get_result();

if (!$result_camera) {
    http_response_code(500);
    echo json_encode(['error' => 'Query failed (camera): ' . $conn->error]);
    $stmt_camera->close();
    $conn->close();
    exit;
}

// Fetch all CameraRecords into an array
$cameraRecords = [];
while ($row = $result_camera->fetch_assoc()) {
    $cameraRecords[] = $row;
}

$stmt_camera->close();

// Step 5: Filter CameraRecords based on matching dates
$filtered_cameraRecords = [];

foreach ($cameraRecords as $cr) {
    $glosId = $cr['glosId'];
    $cr_date = date('Y-m-d', strtotime($cr['startTime']));

    // Check if glosId exists in included_glos and if any of the dates match
    if (isset($included_glos[$glosId])) {
        foreach ($included_glos[$glosId] as $mt_date) {
            if ($mt_date === $cr_date) {
                $filtered_cameraRecords[] = $cr;
                break; // No need to check other dates for this record
            }
        }
    }
}

// Step 6: Update stateVideo to 'DELETE' for each filtered CameraRecord
if (!empty($filtered_cameraRecords)) {
    // Prepare the UPDATE statement
    $sql_update = "UPDATE CameraRecords SET stateVideo = ? WHERE id = ?";
    $stmt_update = $conn->prepare($sql_update);

    if (!$stmt_update) {
        http_response_code(500);
        echo json_encode(['error' => 'Prepare failed (update): ' . $conn->error]);
        $conn->close();
        exit;
    }

    // Define the new stateVideo value
    $new_stateVideo = 'DELETE'; // Adjust this value as needed

    // Begin a transaction for efficiency and to ensure data integrity
    $conn->begin_transaction();

    try {
        foreach ($filtered_cameraRecords as $record) {
            $id = $record['id']; // Assuming 'id' is the primary key

            // Bind parameters: stateVideo (string) and id (integer/string based on your schema)
            $stmt_update->bind_param('si', $new_stateVideo, $id);

            // Execute the statement
            if (!$stmt_update->execute()) {
                throw new Exception('Execution failed (update): ' . $stmt_update->error);
            }
        }

        // Commit the transaction
        $conn->commit();
    } catch (Exception $e) {
        // Rollback the transaction on error
        $conn->rollback();
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
        $stmt_update->close();
        $conn->close();
        exit;
    }

    $stmt_update->close();
} else {
    // No records to update
    // Optionally, you can return a message indicating that no updates were performed
}

// Close the database connection
$conn->close();

// Return the filtered CameraRecords as JSON
echo json_encode(['data' => $filtered_cameraRecords]);
?>
