<?php
// search_nmm.php

// Include the database configuration file
include '../mysql_config.php';

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'error' => 'Database connection failed']));
}

// Initialize SQL query
$sql = "SELECT id, signbank_id, glos, zelfopname, type, thema FROM nmm_data WHERE glos LIKE ?";

// Prepare the statement
$stmt = $conn->prepare($sql);

// Get the search query
$search = isset($_GET['glos']) ? $_GET['glos'] : '';

// Add wildcards for partial matching
$search = '%' . $conn->real_escape_string($search) . '%';

// Bind parameters
$stmt->bind_param("s", $search);

// Execute the query
$stmt->execute();

$result = $stmt->get_result();

// Initialize an array to store the records
$data = [];

// Fetch data
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        // You can modify this part based on your specific needs
        $data[] = $row;
    }
}

// Output the data as JSON
header('Content-Type: application/json');
echo json_encode(['success' => true, 'data' => $data]);

// Close the connection
$stmt->close();
$conn->close();
?>
