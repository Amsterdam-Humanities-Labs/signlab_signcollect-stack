<?php
header("Content-Type: application/json");
include('../mysql_config.php');

// Disable PHP warnings and notices
error_reporting(E_ERROR | E_PARSE);

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    http_response_code(500); // Internal Server Error
    echo json_encode([
        "status" => "error",
        "message" => "Connection failed: " . $conn->connect_error
    ]);
    exit();
}

try {
    // Fetch 'm_file' from GET parameters
    $m_file = filter_input(INPUT_GET, 'm_file', FILTER_SANITIZE_STRING);

    // Remove .mp4 from m_file and replace with .wav
    $m_file = str_replace('.mp4', '.wav', $m_file);
    // echo $m_file;

    if ($m_file) {
        // Prepare statement to check if 'm_file' exists in 'matched_transcriptions'
        $stmt = $conn->prepare("SELECT id, added, m_transcription, date FROM matched_transcriptions WHERE m_file = ?");
        if ($stmt) {
            $stmt->bind_param("s", $m_file);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows > 0) {
                // Fetch the record
                $record = $result->fetch_assoc();


                    // Begin transaction
                    $conn->begin_transaction();

                    try {
                        // Prepare statement to update 'added' from 1 to 0
                        $update_stmt = $conn->prepare("UPDATE matched_transcriptions SET added = 0 WHERE m_file = ?");
                        if ($update_stmt) {
                            $update_stmt->bind_param("s", $m_file);
                            if ($update_stmt->execute()) {
                                // Successfully updated 'matched_transcriptions'

                                // Retrieve necessary fields for updating 'CameraRecords'
                                $glosId = $record['m_transcription'];
                                $mt_date = $record['date']; // Assuming 'date' field is in 'Y-m-d' format

                                // Prepare statement to fetch all 'stopTime' from 'CameraRecords' for the given glosId
                                $cr_stmt = $conn->prepare("SELECT stopTime FROM CameraRecords WHERE glosId = ?");
                                if ($cr_stmt) {
                                    $cr_stmt->bind_param("s", $glosId);
                                    $cr_stmt->execute();
                                    $cr_result = $cr_stmt->get_result();

                                    if ($cr_result->num_rows > 0) {
                                        $matching_cr_found = false; // Flag to check if any matching cr_date is found

                                        while ($cr_record = $cr_result->fetch_assoc()) {
                                            $stopTime = $cr_record['stopTime']; // e.g., "2024-12-18T16:32:23.704Z"

                                            // Convert 'stopTime' to 'Y-m-d' format
                                            $cr_date = date("Y-m-d", strtotime($stopTime));

                                            // Debugging output (you can remove or comment out in production)
                                            // echo $mt_date . " " . $cr_date . "\n";

                                            // Compare dates
                                            if ($mt_date === $cr_date) {
                                                $matching_cr_found = true;

                                                // Proceed to update 'CameraRecords' stateVideo
                                                $update_cr_stmt = $conn->prepare("UPDATE CameraRecords SET stateVideo = 'DELETE' WHERE glosId = ? AND stopTime = ?");
                                                if ($update_cr_stmt) {
                                                    $update_cr_stmt->bind_param("ss", $glosId, $stopTime);
                                                    if ($update_cr_stmt->execute()) {
                                                        // stateVideo updated successfully for this record
                                                    } else {
                                                        // Failed to update stateVideo
                                                        throw new Exception("Failed to update stateVideo for stopTime {$stopTime}: " . $update_cr_stmt->error);
                                                    }
                                                    $update_cr_stmt->close();
                                                } else {
                                                    throw new Exception("Failed to prepare stateVideo update statement: " . $conn->error);
                                                }
                                            }
                                        }

                                            // Now, update signbank_upload for matching rows in matched_transcriptions
                                            $update_signbank_stmt = $conn->prepare("UPDATE matched_transcriptions SET signbank_upload = 2 WHERE m_transcription = ? AND zOg = 'nmm'");
                                            if ($update_signbank_stmt) {
                                                $update_signbank_stmt->bind_param("s", $glosId);
                                                if ($update_signbank_stmt->execute()) {
                                                    // signbank_upload updated successfully
                                                    $response = [
                                                        "status" => "success",
                                                        "message" => "Video marked for deletion successfully, CameraRecords updated, and signbank_upload set to 2.",
                                                        "m_file" => $m_file
                                                    ];
                                                } else {
                                                    // Failed to update signbank_upload
                                                    throw new Exception("Failed to update signbank_upload: " . $update_signbank_stmt->error);
                                                }
                                                $update_signbank_stmt->close();
                                            } else {
                                                throw new Exception("Failed to prepare signbank_upload update statement: " . $conn->error);
                                            }
                                   
                                    } else {
                                        // No matching CameraRecords found
                                        $response = [
                                            "status" => "warning",
                                            "message" => "Video marked for deletion, but no matching CameraRecords found.",
                                            "m_file" => $m_file,
                                            "glosId" => $glosId
                                        ];
                                    }
                                    $cr_stmt->close();
                                } else {
                                    throw new Exception("Failed to prepare CameraRecords select statement: " . $conn->error);
                                }
                            } else {
                                // Failed to update matched_transcriptions
                                throw new Exception("Failed to update matched_transcriptions: " . $update_stmt->error);
                            }
                            $update_stmt->close();
                        } else {
                            throw new Exception("Failed to prepare matched_transcriptions update statement: " . $conn->error);
                        }

                        // Commit transaction if everything went well
                        $conn->commit();
                    } catch (Exception $e) {
                        // Rollback transaction on error
                        $conn->rollback();
                        $response = [
                            "status" => "error",
                            "message" => "Transaction failed: " . $e->getMessage()
                        ];
                    }
                
            } else {
                $response = [
                    "status" => "error",
                    "message" => "No video found with the provided m_file.",
                    "received_m_file" => $m_file
                ];
            }
            $stmt->close();
        } else {
            $response = [
                "status" => "error",
                "message" => "Failed to prepare select statement.",
                "error" => $conn->error
            ];
        }
    } else {
        $response = [
            "status" => "error",
            "message" => "Missing 'm_file' parameter.",
            "received_parameters" => $_GET
        ];
    }

    echo json_encode($response);
} catch (Exception $e) {
    http_response_code(500); // Internal Server Error
    echo json_encode([
        "status" => "error",
        "message" => "An unexpected error occurred.",
        "error" => $e->getMessage()
    ]);
} finally {
    // Close the database connection
    $conn->close();
}
?>
