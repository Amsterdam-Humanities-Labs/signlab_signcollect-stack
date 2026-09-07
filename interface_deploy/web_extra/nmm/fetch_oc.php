<?php
// Set the response content type to JSON
header('Content-Type: application/json');

// Enable error reporting for runtime errors (optional for debugging; disable in production)
error_reporting(E_ERROR | E_PARSE);

// Include the database configuration file
include '../mysql_config.php';

// Create a new MySQLi connection using the provided credentials
$conn = new mysqli($servername, $username, $password, $database);

// Check for a successful connection
if ($conn->connect_error) {
    // Return a JSON error response and terminate the script
    die(json_encode([
        'success' => false,
        'error' => 'Database connection failed: ' . $conn->connect_error
    ]));
}

// Retrieve and sanitize the 'glos' parameter from the GET request
$glos = isset($_GET['glos']) ? trim($_GET['glos']) : '';

// Validate the 'glos' parameter
if (empty($glos)) {
    echo json_encode([
        'success' => false,
        'error' => 'Missing or empty "glos" parameter.'
    ]);
    $conn->close();
    exit;
}

// Prepare the SQL query to select 'zelfopname' where 'type' is 'oc' and 'glos' matches
$sql = "SELECT zelfopname FROM nmm_data WHERE type = 'oc' AND glos LIKE ?";

// Initialize a prepared statement
$stmt = $conn->prepare($sql);

// Check if the statement was prepared successfully
if (!$stmt) {
    echo json_encode([
        'success' => false,
        'error' => 'Failed to prepare the SQL statement: ' . $conn->error
    ]);
    $conn->close();
    exit;
}

// Bind the 'glos' parameter to the SQL statement with wildcard characters for partial matching
$search_glos = '%' . $glos . '%';
$stmt->bind_param("s", $search_glos);

// Execute the prepared statement
$stmt->execute();

// Retrieve the result set from the executed statement
$result = $stmt->get_result();

// Initialize an array to store the retrieved 'zelfopname' values
$zelfopnames = [];

// Fetch each row and add the 'zelfopname' to the array
while ($row = $result->fetch_assoc()) {
    // Optionally, sanitize the 'zelfopname' if it will be displayed in a web context
    $zelfopnames[] = htmlspecialchars($row['zelfopname'], ENT_QUOTES, 'UTF-8');
}

// Close the statement and the database connection
$stmt->close();
$conn->close();

// Return the successful JSON response with the retrieved 'zelfopname' data
echo json_encode([
    'success' => true,
    'zelfopnames' => $zelfopnames
]);
?>
