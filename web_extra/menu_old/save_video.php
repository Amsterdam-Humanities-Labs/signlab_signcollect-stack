<?php

include('/web/mysql_config.php');
$data = file_get_contents('php://input');
$glosId = $_GET['id'];
$wie = $_GET['userid'];
// Set the response content type to JSON
header('Content-Type: application/json');
//disable php warning
error_reporting(E_ERROR | E_PARSE);


// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

$randomString = generateRandomString(64);

/**
 * Fetches the zelfopname column from the form_data table and updates it with a new value.
 *
 * @param string $glosId The ID of the record in the form_data table.
 * @param string $randomString The new value to be added to the zelfopname column.
 * @param mysqli $conn The database connection object.
 * @return void
 */
// Fetch the zelfopname column from form_data table
$sql = "SELECT zelfopname FROM form_data WHERE id = '" . $glosId . "'";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $zelfopname = $row['zelfopname'];

    // Attempt to convert the zelfopname to an array
    $zelfopnameArray = json_decode($zelfopname, true);

    // Check if the conversion was successful or if zelfopname is empty
    if (is_array($zelfopnameArray) || empty($zelfopname)) {
        // Initialize as an array if zelfopname was empty or not a valid JSON array
        if (!is_array($zelfopnameArray)) {
            $zelfopnameArray = [];
        }

        // Add $randomString as the last item in the array
        $zelfopnameArray[] = $randomString. '.webm';

        $zelfopnameArray = array_values($zelfopnameArray); // Reindex the array

        // Convert the array back to a JSON string
        $updatedZelfopname = json_encode($zelfopnameArray);

        // Update the zelfopname column in form_data table
        $updateSql = "UPDATE form_data SET process_zelfopname = '1', logboek = CONCAT(logboek, '\nZelfopname aangemaakt door ".$wie."'), zelfopname = '" . $updatedZelfopname . "' WHERE id = '" . $glosId . "'";
        if ($conn->query($updateSql) === TRUE) {
            // Update success
            $response = array("success" => "Record updated successfully");
        } else {
            // Update failed
            $response = array("error" => "Error updating record: " . $conn->error);
        }
    } else {
        // Handle the case when $zelfopname is not a JSON array and is not empty
        // This can be initializing a new array with $randomString as its first item
        $zelfopnameArray = [$randomString . '.webm'];
        $updatedZelfopname = json_encode($zelfopnameArray);
        $updateSql = "UPDATE form_data SET process_zelfopname = '1', zelfopname = '" . $updatedZelfopname . "' WHERE id = '" . $glosId . "'";
        if ($conn->query($updateSql) === TRUE) {
            $response = array("success" => "Record updated successfully with new array");
        } else {
            $response = array("error" => "Error updating record: " . $conn->error);
        }
    }
} else {
    // Handle the case when no record is found
    $response = array("error" => "No record found");
}


// Check if the POST request contains a Blob
if (isset($data)) {
    // Specify the directory where you want to save the video file
    $upload_directory = '/web/uploads/';

    // Generate a unique filename for the video (you can use any naming convention you prefer)
    $video_filename = $randomString . '.webm';

    // Create the full path to the video file
    $video_path = $upload_directory . $video_filename;

    // Save the Blob data to the video file
    if (file_put_contents($video_path, $data) !== false) {

        // Use prepared statements to prevent SQL injection
        $stmt = $conn->prepare($sql);
        if ($stmt) {

            // Assign the value of the unique identifier (e.g., from $updatedData)

            // Execute the update
            if ($stmt->execute()) {

                // Video has been successfully saved
                $response = array(
                    'success' => true,
                    'message' => 'Video has been successfully saved'
                );
            } else {
                $response = array("error" => "Error updating data");
            }

            $stmt->close();
        } else {
            $response = array("error" => "Prepared statement error");
        }

        // Close the database connection
        $conn->close();
    } else {
        // Failed to save the video
        $response = array("error" => "Error: Unable to save the video.");
    }
} else {
    // No Blob data received
    $response = array("error" => "Error: No video data received.");
}

function generateRandomString($length = 64)
{
    if ($length <= 0) {
        return false;
    }

    // Calculate the number of bytes needed to achieve the desired length
    $bytes = ceil($length / 2);

    // Generate random bytes
    $randomBytes = random_bytes($bytes);

    // Convert the random bytes to a hexadecimal string
    $randomString = bin2hex($randomBytes);

    // Ensure the string doesn't exceed the specified length
    return substr($randomString, 0, $length);
}

echo json_encode($response);

?>
