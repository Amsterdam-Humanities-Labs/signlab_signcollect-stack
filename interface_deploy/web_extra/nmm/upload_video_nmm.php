<?php
header('Content-Type: application/json');
include('../mysql_config.php');

// Connect to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'error' => 'Database connection failed']));
}

// Check if the video file and required data are sent
if (isset($_FILES['video']) && isset($_POST['glos'])) {
    $type = 'oc'; // Always assume it's oral component as per requirement
    $video = $_FILES['video'];
    $glos = $_POST['glos'];

    // Define the upload directory and generate a unique filename
    $uploadDir = '/var/www/html/uploads/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    // Sanitize glos to create a safe filename
    $safeGlos = preg_replace('/[^A-Za-z0-9_\-]/', '_', $glos);
    $videoFileName = uniqid('nmm_', true) . '_' . $safeGlos . '.webm';
    $videoPath = $uploadDir . $videoFileName;

    // Move the uploaded video to the upload directory
    if (move_uploaded_file($video['tmp_name'], $videoPath)) {
        // Extract a thumbnail from the video at 1 second using FFmpeg
        $thumbnailPath = $uploadDir . pathinfo($videoFileName, PATHINFO_FILENAME) . '.jpg'; // Save thumbnail in the same directory

        // FFmpeg command to extract the thumbnail at 1 second
        $command = "ffmpeg -i \"$videoPath\" -ss 00:00:01 -vframes 1 \"$thumbnailPath\" 2>&1";
        exec($command, $output, $return_var);

        if ($return_var === 0) {
            $thumbnailStatus = "Thumbnail created at: $thumbnailPath";
        } else {
            $thumbnailStatus = "Failed to create thumbnail. FFmpeg output: " . implode("\n", $output);
        }

        // Check if the record exists based on 'glos' and 'type=oc'
        $checkStmt = $conn->prepare("SELECT COUNT(*) FROM nmm_data WHERE glos = ? AND type = ?");
        $checkStmt->bind_param("ss", $glos, $type);
        $checkStmt->execute();
        $checkStmt->bind_result($count);
        $checkStmt->fetch();
        $checkStmt->close();

        if ($count > 0) {
            // Update query
            $stmt = $conn->prepare("UPDATE nmm_data SET zelfopname = ? WHERE glos = ? AND type = ?");
            $stmt->bind_param("sss", $videoFileName, $glos, $type);
        } else {
            // Insert query
            $stmt = $conn->prepare("INSERT INTO nmm_data (zelfopname, type, glos) VALUES (?, ?, ?)");
            $stmt->bind_param("sss", $videoFileName, $type, $glos);
        }

        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Video uploaded and database updated successfully',
                'video' => $videoFileName,
                'thumbnail' => basename($thumbnailPath),
                'thumbnail_status' => $thumbnailStatus
            ]);
        } else {
            echo json_encode(['success' => false, 'error' => 'Failed to update database']);
        }

        $stmt->close();
    } else {
        echo json_encode(['success' => false, 'error' => 'Failed to save the uploaded video']);
    }
} else {
    echo json_encode(['success' => false, 'error' => 'Invalid request data']);
}

$conn->close();
?>
