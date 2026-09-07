<?php
// Replace these variables with your actual database credentials
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
$labels = is_array($updatedData['labels']) ? json_encode($updatedData['labels']) : $updatedData['labels'];

$sql = "UPDATE form_data SET labels = ? WHERE id = ?";
$stmt = $conn->prepare($sql);
if ($stmt) {
    $stmt->bind_param('si', $labels, $id);
    if ($stmt->execute()) {
        echo json_encode(array("message" => "Labels updated successfully"));
    } else {
        echo json_encode(array("error" => "Error updating data: " . $stmt->error));
    }
    $stmt->close();
} else {
    echo json_encode(array("error" => "Prepared statement error: " . $conn->error));
}

$conn->close();
?>
