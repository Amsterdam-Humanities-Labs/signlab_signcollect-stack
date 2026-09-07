<?php
// Replace these variables with your actual database credentials
include('/web/mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get the updated data from the POST request
$updatedData = json_decode($_POST['updatedData'], true);
print_r($updatedData);

$updateAssignments = array();
$bindParams = array();
$paramTypes = '';

// Handle deleteVideo if set
if (isset($updatedData['deleteVideo'])) {
    $lala = $updatedData['deleteVideo'];
    
    $sql = "SELECT * FROM form_data WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $updatedData['id']);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if($result->num_rows > 0){
        $row = $result->fetch_assoc();
        $zelfopname = $row['zelfopname'];
        $zelfopnameArray = json_decode($zelfopname, true);

        for ($i = 0; $i < count($zelfopnameArray); $i++) {
            if ($zelfopnameArray[$i] == $lala) {
                unset($zelfopnameArray[$i]);
            }
        }
        $zelfopnameArray = array_values($zelfopnameArray);
        $updatedZelfopname = json_encode($zelfopnameArray);
        $updateAssignments[] = "zelfopname = ?";
        $paramTypes .= 's';
        $bindParams[] = $updatedZelfopname;
    }
    $stmt->close();
}

// Prepare the update assignments and bind parameters
foreach ($updatedData as $key => $value) {
    // Skip empty keys and special keys
    if ($key === '' || in_array($key, ['id', 'logboekUpdate', 'deleteVideo'])) {
        continue;
    }
    $updateAssignments[] = "$key = ?";
    $paramTypes .= 's';
    if (is_array($value)) {
        $value = json_encode($value);
    }
    $bindParams[] = $value;
}


// Always prepare logboek update parameter
$logboekUpdate = isset($updatedData['logboekUpdate']) ? "\n" . $updatedData['logboekUpdate'] : "";
array_unshift($bindParams, $logboekUpdate);
$paramTypes = 's' . $paramTypes;

print_r($logboekUpdate);
    
$bindParams[] = $updatedData['id'];
$paramTypes .= 'i';

$updateAssignmentsString = implode(", ", $updateAssignments);
$sql = "UPDATE form_data SET 
  logboek = CONCAT(COALESCE(logboek, ''), CONVERT(? USING latin1)), 
  $updateAssignmentsString 
WHERE id = ?";

print_r($sql);

$stmt = $conn->prepare($sql);
if ($stmt) {
    // Bind parameters
    $stmt->bind_param($paramTypes, ...$bindParams);

    if ($stmt->execute()) {
        $response = array("message" => "Data updated successfully");
        echo json_encode($response);
    } else {
        $response = array("error" => "Error updating data: " . $stmt->error);
        echo json_encode($response);
    }

    $stmt->close();
} else {
    $response = array("error" => "Prepared statement error: " . $conn->error);
    echo json_encode($response);
}

// Close the database connection
$conn->close();
?>
