<?php
// Enable error reporting for errors and parse errors only
error_reporting(E_ERROR | E_PARSE);

// Include the database configuration file
include '../mysql_config.php';


//for this script we want to move the videofile from zOg=nmm to nmm_oc in matched_transcriptions

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);
// Check connection
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'error' => 'Connection failed: ' . $conn->connect_error]));
}


//retrieve m_file via GET

$m_file = isset($_GET['m_file']) ? trim($_GET['m_file']) : '';
$type = isset($_GET['type']) ? trim($_GET['type']) : '';

//get basename from m_file
$m_file = basename($m_file);
//remove extension
$m_file = pathinfo($m_file, PATHINFO_FILENAME);

// Initialize SQL query with proper WHERE clause handling
$sql = "SELECT id, m_file, m_transcription FROM matched_transcriptions WHERE m_file LIKE CONCAT('%', ?, '%') AND (zOg = 'nmm' OR zOg = 'nmm_oc')";

// Prepare and execute the SELECT statement
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $m_file);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $id = $result->fetch_assoc()['id'];
    // Prepare the UPDATE statement for matched_transcriptions
    $update_sql = "UPDATE matched_transcriptions SET zOg = ? WHERE id = ?";
    $update_stmt = $conn->prepare($update_sql);
    $update_stmt->bind_param("ss", $type, $id);

    if ($update_stmt->execute()) {
        // Retrieve m_transcription from the selected record
        $row = $result->fetch_assoc();
        $m_transcription = $row['m_transcription'];

        // Prepare the UPDATE statement for nmm_data
        $update_nmm_sql = "UPDATE nmm_data SET type = ? WHERE id = ?";
        $update_nmm_stmt = $conn->prepare($update_nmm_sql);
        $update_nmm_stmt->bind_param("ss", $type, $m_transcription);

        if ($update_nmm_stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'zOg updated to nmm_oc and type in nmm_data updated']);
        } else {
            echo json_encode(['success' => false, 'error' => 'nmm_data update failed: ' . $conn->error]);
        }
    } else {
        echo json_encode(['success' => false, 'error' => 'Update failed: ' . $conn->error]);
    }
} else {
    echo json_encode(['success' => false, 'error' => 'No matching record found']);
}

$conn->close();
?>
