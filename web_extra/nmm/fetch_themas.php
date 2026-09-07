<?php
// Include the database configuration file
include '../mysql_config.php';

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Initialize SQL query to get unique thema values
$sql = "SELECT DISTINCT thema FROM nmm_data WHERE thema IS NOT NULL AND thema != ''";

// Execute the query
$result = $conn->query($sql);

// Initialize an array to store the unique thema values
$themas = [];

// Fetch data
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $themas[] = ['thema' => $row['thema']];
    }
}

// Output the data in the format { "rows": [ { "thema": "value" }, ... ] }
header('Content-Type: application/json');
echo json_encode(['rows' => $themas]);

// Close the connection
$conn->close();
?>
