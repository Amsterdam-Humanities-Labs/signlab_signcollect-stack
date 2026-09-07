<?php
// Enable error reporting for errors and parse errors only
error_reporting(E_ERROR | E_PARSE);

// Set Content-Type to JSON
header('Content-Type: application/json');

// Include the database configuration file
include '../mysql_config.php'; // Ensure the path is correct

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    echo json_encode(['success' => false, 'error' => 'Connection failed: ' . $conn->connect_error]);
    exit();
}

// Retrieve video_url via GET
$video_url = isset($_GET['video_url']) ? trim($_GET['video_url']) : '';

if (empty($video_url)) {
    echo json_encode(['success' => false, 'error' => 'No video_url parameter provided.']);
    exit();
}

// Extract basename from video_url
$basename = basename($video_url);

// Remove extension
$m_file = pathinfo($basename, PATHINFO_FILENAME);

// Initialize SQL query with proper WHERE clause handling
// We want to match m_file with the given filename and check for zOg = 'nmm' or 'nmm_oc'
$sql = "SELECT zOg FROM matched_transcriptions WHERE m_file LIKE CONCAT('%', ?, '%') AND (zOg = 'nmm' OR zOg = 'nmm_oc')  AND added = '1' LIMIT 1";

// Prepare and execute the SELECT statement
$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode(['success' => false, 'error' => 'Prepare failed: ' . $conn->error]);
    exit();
}

$stmt->bind_param("s", $m_file);

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'error' => 'Execute failed: ' . $stmt->error]);
    $stmt->close();
    exit();
}

$result = $stmt->get_result();

if ($result->num_rows > 0) {
    // Fetch the first matching row
    $row = $result->fetch_assoc();
    $type = $row['zOg']; // 'nmm' or 'nmm_oc'
    $added = 1; // Since it exists and matches the type

    echo json_encode(['success' => true, 'type' => $type, 'added' => $added]);
} else {
    // No matching video found or does not meet the criteria
    echo json_encode(['success' => true, 'type' => null, 'added' => 0]);
}

$stmt->close();
$conn->close();
?>
