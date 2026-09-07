<?php
// updateVideo.php

// Include database configuration
include('/web/mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get JSON payload from request body
$updatedData = json_decode(file_get_contents('php://input'), true);
if (!isset($updatedData['id']) || !isset($updatedData['labels'])) {
    echo json_encode(array("error" => "Invalid data"));
    exit;
}

$id = $updatedData['id'];
$videoUrl = $updatedData['labels'];
//get first item of videoUrl array
$videoUrl = $videoUrl[0];

// Step 1: Get the basename (this may include a query string)
$basename = basename($videoUrl); // e.g. "12-A-2579.mp4?1741277145010"

// Remove query string if present
$basename = strtok($basename, '?'); // e.g. "12-A-2579.mp4"

// Convert the processed basename into an array and JSON encode it
$jsonValue = json_encode(array($basename));

// Extract the numeric value from basename using regex (value between - and _nme)
$signbankValue = '';
if (preg_match('/-(\d+)_nme/', $basename, $matches)) {
    $signbankValue = $matches[1];
} elseif (preg_match('/-(\d+)\./', $basename, $matches)) {
    // Alternative pattern if _nme is not present but we have a number before file extension
    $signbankValue = $matches[1];
}

// Fixed SQL query - properly set both fields
$sql = "UPDATE form_data SET zelfopname = ?, signbank = ? WHERE id = ?";
$stmt = $conn->prepare($sql);
if ($stmt) {
    $stmt->bind_param('ssi', $jsonValue, $signbankValue, $id);
    if ($stmt->execute()) {
        echo json_encode(array(
            "message" => "Video updated successfully", 
            "updatedValue" => $basename,
            "signbankValue" => $signbankValue
        ));
    } else {
        echo json_encode(array("error" => "Error updating video: " . $stmt->error));
    }
    $stmt->close();
} else {
    echo json_encode(array("error" => "Prepared statement error: " . $conn->error));
}

$conn->close();
?>