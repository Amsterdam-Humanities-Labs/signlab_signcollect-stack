<?php
// Database configuration
include('../mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die(json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]));
}

// Get the input data
$input = json_decode(file_get_contents('php://input'), true);
$signbank_id = $input['signbank_id'] ?? null;
$type = $input['type'] ?? null;
$glos = $input['glos'] ?? '';
$thema = $input['thema'] ?? '';
$zelfopname = $input['zelfopname'] ?? '';

// Validate required parameters
if (!$signbank_id || !$type) {
    echo json_encode(['error' => 'Missing required parameters']);
    exit;
}


// Check if the record with the specific type already exists
$checkStmt = $conn->prepare("SELECT COUNT(*) FROM nmm_data WHERE glos = ? AND (type = 'ready' OR type = 'not_ready')");
$checkStmt->bind_param("s", $glos);
$checkStmt->execute();
$checkStmt->bind_result($count);
$checkStmt->fetch();
$checkStmt->close();

if ($count > 0) {
    // Record exists, update it
    //when it's already on ready, then set to not_ready. if it's already on not_ready, then set to ready

    $stmt = $conn->prepare("UPDATE nmm_data SET zelfopname = ?, glos = ?, thema = ?, type = ? WHERE glos = ? AND (type = 'ready' OR type = 'not_ready')");
    $stmt->bind_param("sssss", $zelfopname, $glos, $thema, $type, $glos);
    $action = 'updated';

} else {
    // Record does not exist, insert it
    $stmt = $conn->prepare("INSERT INTO nmm_data (signbank_id, type, zelfopname, glos, thema) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("sssss", $signbank_id, $type, $zelfopname, $glos, $thema);
    $action = 'inserted';
}

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'action' => $action, 'type' => $type]);
} else {
    echo json_encode(['error' => 'Database operation failed']);
}

$stmt->close();
$conn->close();
?>
