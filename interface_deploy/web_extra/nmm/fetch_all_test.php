<?php
// Include the database configuration file
include '../mysql_config.php';

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Initialize SQL query
$sql = "SELECT id, signbank_id, glos, zelfopname, type, thema FROM nmm_data";

// Check if 'thema' is set in the URL
if (isset($_GET['thema']) && !empty($_GET['thema'])) {
    $thema = $conn->real_escape_string($_GET['thema']);
    $sql .= " WHERE thema = '$thema'";
}

// Execute the query
$result = $conn->query($sql);

// Initialize an array to store the records
$data = [];

// Fetch data
if ($result->num_rows > 0) {
    // Fetch each row from the first query
    while ($row = $result->fetch_assoc()) {
        // Prepare the second SQL query
        $sqla = "SELECT camera1, camera2, camera3, camera4, camera5, videoTop, datetime_ms, user 
                 FROM CameraRecords 
                 WHERE zOg='nmm' AND glosId = ? AND (user LIKE ? OR ? = '%')";
        
        $stmt2 = $conn->prepare($sqla);
        
        // Define $userId as an empty string or adjust based on your actual requirements
        $userId = isset($_GET['userId']) ? $_GET['userId'] : '%';
        
        // Bind parameters correctly
        $stmt2->bind_param('iss', $row['id'], $userId, $userId);
        $stmt2->execute();
        $result2 = $stmt2->get_result();

        // Fetch all video records associated with the current row
        $videos = [];
        while ($row2 = $result2->fetch_assoc()) {
            $videos[] = $row2;
        }

        //when there is ready in type, then we convert it to gc
        if ($row['type'] == 'ready') {
            //first check if there is already a record with type gc, if so then we continue. 
            $checkStmt = $conn->prepare("SELECT COUNT(*) FROM nmm_data WHERE signbank_id = ? AND type = ?");
            $type = 'gc';
            $checkStmt->bind_param("ss", $row['signbank_id'], $type);
            $checkStmt->execute();
            $checkStmt->bind_result($count);
            $checkStmt->fetch();
            $checkStmt->close();
            if ($count > 0) {
                continue;
            }


            $row['type'] = 'gc';
        }

        //if zelfopname is still empty, get zelfopname from form_Data
            $stmt3 = $conn->prepare("SELECT zelfopname FROM form_data WHERE id = ?");
            $stmt3->bind_param("s", $row['signbank_id']);
            $stmt3->execute();
            $stmt3->bind_result($zelfopname);
            $stmt3->fetch();
            $stmt3->close();
            // print_r($zelfopname);
            //$zelfopname is json array, convert it to php array and check if it has one element then get the first element
            if (is_string($zelfopname)) {
                $zelfopname = json_decode($zelfopname, true);
            }
            if (is_array($zelfopname) && count($zelfopname) === 1) {
                $zelfopname = $zelfopname[0];
            }
            $row['zelfopname'] = $zelfopname;


        // //if it is still empty then get signbank video
        // if (is_array($row['zelfopname']) && count($row['zelfopname']) === 0 || $row['zelfopname'] == "") {
        //     $row['zelfopname'] = $row['glos'] . ".mp4";
        // }

        // Create the response for each row
        $response = [
            'id' => $row['id'],
            'signbank_id' => $row['signbank_id'],
            'glos' => $row['glos'],
            'zelfopname' => $row['zelfopname'], // URL to the video
            'type' => $row['type'],
            'videos' => $videos
        ];

        // Add the response to the data array
        $data[] = $response;

        // Close the second statement to avoid memory issues
        $stmt2->close();
    }
}

// Output the data as JSON
header('Content-Type: application/json');
echo json_encode($data);

// Close the connection
$conn->close();
?>
