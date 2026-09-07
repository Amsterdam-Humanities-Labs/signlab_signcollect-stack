<?php
// Replace these variables with your actual database credentials
include('/web/mysql_config.php');


// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Fetch user data from the 'users' table
$sql = "SELECT userId, user FROM users";
$result = $conn->query($sql);

// Create an array to store the fetched data
$userData = array();

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $userData[] = [
            'userid' => $row['userId'],
            'user' => $row['user']
        ];
    }
}

// Close the database connection
$conn->close();

// Return the user data as JSON
header("Content-Type: application/json");
echo json_encode($userData);
?>
