<?php
// Database configuration
include('../mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die(json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]));
}

// Validate and get input parameters
$id = isset($_GET['id']) ? $_GET['id'] : null;

// Sanitize input to prevent SQL injection
$id = $id !== null ? $conn->real_escape_string($id) : null;

$response = [];

   // SQL query to select the required fields
    $sqla = "SELECT m_file, r_file, l_file, a_file, b_file 
             FROM matched_transcriptions 
             WHERE zOg='nmm' AND definitive_outcome = ? AND added = 1";
    
    $stmt2 = $conn->prepare($sqla);
    
    // Check if the statement was prepared successfully
    if ($stmt2) {
        // Bind parameters correctly
        $stmt2->bind_param('s', $id);
        $stmt2->execute();
        $result2 = $stmt2->get_result();

        // Fetch the associated records
        if ($row2 = $result2->fetch_assoc()) {
            $response = [
                'm_file' => $row2['m_file'],
                'r_file' => $row2['r_file'],
                'l_file' => $row2['l_file'],
                'a_file' => $row2['a_file'],
                'b_file' => $row2['b_file'],
            ];
        } else {
            $response = ['error' => 'No records found.'];
        }

        // Free the result and close the statement
        $result2->free();
        $stmt2->close();
    } else {
        $response = ['error' => 'Failed to prepare the SQL statement.'];
    }


// Return the combined response as JSON
echo json_encode($response);

// Close the database connection
$conn->close();
?>
