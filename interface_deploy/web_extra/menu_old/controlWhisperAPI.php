<?php
// data_fetch.php

include('/web/mysql_config.php');

$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// SQL query to fetch records where ready = 1 and there are issues
$sql = "SELECT date, ready, issues FROM studio_data WHERE ready = 1 AND issues != ''";
$result = $conn->query($sql);

$data = [];

if ($result->num_rows > 0) {
    // Fetch data into an array
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
}

$conn->close();

// Return data as a JSON response
echo json_encode($data);
?>
