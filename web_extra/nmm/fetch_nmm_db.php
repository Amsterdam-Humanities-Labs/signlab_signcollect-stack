<?php
// Enable error reporting for errors and parse errors only
error_reporting(E_ERROR | E_PARSE);

// Include the database configuration file
include '../mysql_config.php';

// Create connection using the included configuration
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'error' => 'Connection failed: ' . $conn->connect_error]));
}

// Retrieve and sanitize GET parameters
$glos = isset($_GET['glos']) ? trim($_GET['glos']) : '';
$thema = isset($_GET['thema']) ? trim($_GET['thema']) : '';
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 100;
$offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;

// Initialize SQL query with proper WHERE clause handling
$sql = "SELECT id, zelfopname, glos, thema, signbank FROM form_data";
$conditions = [];
$params = [];
$types = '';

// Apply filters
if (!empty($glos)) {
    $conditions[] = "glos LIKE ?";
    $params[] = '%' . $glos . '%';
    $types .= 's';
}

if (!empty($thema)) {
    $conditions[] = "thema = ?";
    $params[] = $thema;
    $types .= 's';
}

if (!empty($conditions)) {
    $sql .= " WHERE " . implode(" AND ", $conditions);
}

$sql .= " LIMIT ? OFFSET ?";
$params[] = $limit;
$params[] = $offset;
$types .= 'ii';

// Prepare the statement
$stmt = $conn->prepare($sql);

// Bind parameters if any
if (!empty($types)) {
    $stmt->bind_param($types, ...$params);
}

// Execute the query
$stmt->execute();
$result = $stmt->get_result();

// Initialize an array to store the records
$data = [];

/**
 * Function to process nmm_data queries and append responses
 *
 * @param mysqli $conn
 * @param string $signbank_id
 * @param string $thema_condition ('ALLES' or 'NOT_ALLES')
 * @param array $row
 * @param array &$data
 */
function process_nmm_data($conn, $signbank_id, $thema_condition, $row, &$data) {
    // Determine the SQL condition based on thema_condition
    if ($thema_condition === 'ALLES') {
        $thema_sql = "thema LIKE 'ALLES'";
    } else {
        $thema_sql = "thema NOT LIKE 'ALLES'";
    }

    // Prepare the query
    $nd_query = "SELECT * FROM nmm_data WHERE signbank_id = ? AND glos NOT LIKE '' AND $thema_sql";
    $nd_stmt = $conn->prepare($nd_query);
    if (!$nd_stmt) {
        // Handle prepare error
        return;
    }
    $nd_stmt->bind_param("s", $signbank_id);
    $nd_stmt->execute();
    $nd_result = $nd_stmt->get_result();

    // If no results, add the base response
    if ($nd_result->num_rows === 0) {
        $response = [
            'id' => $row['id'],
            'glos' => htmlspecialchars($row['glos'], ENT_QUOTES, 'UTF-8'),
            'zelfopname' => $row['zelfopname'] !== null ? htmlspecialchars($row['zelfopname'], ENT_QUOTES, 'UTF-8') : null,
            'type' => 'zelfopname GC',
            'thema' => $row['thema'] !== null ? htmlspecialchars($row['thema'], ENT_QUOTES, 'UTF-8') : null,
            'videos' => [],
            'processed' => [],
        ];
        $data[] = $response;
        return;
    }

    while ($nd_row = $nd_result->fetch_assoc()) {
        $type = $nd_row['type'];  

        // Handle 'ready' type by converting to 'gc' if necessary
        if ($nd_row['type'] === 'ready') {
            // Check if there is already a record with type 'gc' for the same signbank_id
            $checkStmt = $conn->prepare("SELECT COUNT(*) FROM nmm_data WHERE signbank_id = ? AND type = 'gc'");
            if ($checkStmt) {
                $checkStmt->bind_param("s", $nd_row['signbank_id']);
                $checkStmt->execute();
                $checkStmt->bind_result($count);
                $checkStmt->fetch();
                $checkStmt->close();

                if ($count > 0) {
                    continue; // Skip this record if a 'gc' type already exists
                }

                // Convert type to 'gc'
                $type = 'GC';
            }
        }

        // Decode 'zelfopname' assuming it's a JSON-encoded array
        $zelfopname_array = json_decode($nd_row['zelfopname'], true);
        $video_links = [];
        if (is_array($zelfopname_array)) {
            foreach ($zelfopname_array as $video_file) {
                // Construct full video URL
                $video_links[] = "gebarenoverleg_media/studioFilesMini/raw/" . htmlspecialchars($video_file, ENT_QUOTES, 'UTF-8');
            }
        }

        // Fetch associated videos from 'matched_transcriptions'
        // Assuming 'm_file' contains the video filenames
        $videos = [];
        $processed = [];
        $videoStmt = $conn->prepare("SELECT m_file, post_processed FROM matched_transcriptions WHERE definitive_outcome = ? AND zOg = 'nmm' AND added = 1");
        if ($videoStmt) {
            $videoStmt->bind_param("i", $nd_row['id']);
            $videoStmt->execute();
            $videoResult = $videoStmt->get_result();
            while ($videoRow = $videoResult->fetch_assoc()) {
                // Replace .wav with .mp4 for video files
                $videoFile = str_replace('.wav', '.mp4', $videoRow['m_file']);
                $videos[] = $videoFile;
                if($videoRow['post_processed'] == 1){
                    $processed[] = $videoFile;
                }
                else
                {
                    $processed[] = '';
                }
            }
            $videoStmt->close();
        }

        // Handle 'zelfopname' field
        if (strpos($row['zelfopname'], '.mp4') !== false) {
            $zelfopname = json_decode($row['zelfopname'], true);
            if (is_array($zelfopname) && isset($zelfopname[0])) {
                $zelfopname = "gebarenoverleg_media/studioFilesMini/raw/" . htmlspecialchars($zelfopname[0], ENT_QUOTES, 'UTF-8');
            } else {
                $zelfopname = '';
            }
        } else {
            $zelfopname = !empty($nd_row['zelfopname']) ? htmlspecialchars($nd_row['zelfopname'], ENT_QUOTES, 'UTF-8') : null;
        }

        // Construct the response for each row
        $response = [
            'id' => $nd_row['id'],
            'glos' => htmlspecialchars($row['glos'], ENT_QUOTES, 'UTF-8'),
            'zelfopname' => $zelfopname,
            'type' => htmlspecialchars($type, ENT_QUOTES, 'UTF-8'),
            'videos' => $videos,
            'processed' => $processed,
            
        ];

        // Add the response to the data array
        $data[] = $response;
    }

    $nd_stmt->close();
}

// Fetch data from form_data
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        // Process nmm_data where thema NOT LIKE 'ALLES'
        process_nmm_data($conn, $row['id'], 'NOT_ALLES', $row, $data);

        // Process nmm_data where thema LIKE 'ALLES'
        process_nmm_data($conn, $row['signbank'], 'ALLES', $row, $data);
    }
}

// Close the initial statement
$stmt->close();

// Post-processing: Remove duplicates and conditionally exclude 'thema'
$unique_data = [];
$excluded_keywords = ['GEBARENSTRAND', 'OLINE', 'MOCAP', 'GOMER'];

foreach ($data as $entry) {
    $id = $entry['id'];

    // Skip duplicate IDs
    if (isset($unique_data[$id])) {
        continue;
    }

    //check if the entry contains excluded keywords
    //if so, skip the entry
    $skip = false;
    foreach ($excluded_keywords as $keyword) {
        if (strpos($entry['thema'], $keyword) !== false) {
            $skip = true;
            break;
        }
    }

    if ($skip) {
        continue;
    }


    // Add the processed entry to unique_data
    $unique_data[$id] = $entry;
}

// Replace $data with the unique, processed entries
$data = array_values($unique_data);

// Output the data as JSON
header('Content-Type: application/json');
echo json_encode(['success' => true, 'data' => $data]);

// Close the connection
$conn->close();
?>
