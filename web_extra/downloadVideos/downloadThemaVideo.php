<?php

// signcollect-lib's install-root resolver: sc_path(), sc_dir(), sc_root().
// Vendored shim - it finds /web/lib/paths.php, or falls back to /web.
require_once __DIR__ . '/../sc_paths.php';

error_reporting(E_ERROR | E_PARSE);
set_time_limit(300); // Set to 5 minutes to handle large files

// Ensure the zipFiles directory exists
$zipDir = __DIR__ . '/zipFiles';
if (!file_exists($zipDir)) {
    mkdir($zipDir, 0755, true);
}

// Get the thema and labels parameters from POST request
$thema = isset($_POST['thema']) ? $_POST['thema'] : '';
$labels = isset($_POST['labels']) ? json_decode($_POST['labels'], true) : [];

// Validate that at least one filter is provided
if (empty($thema) && (empty($labels) || !is_array($labels))) {
    echo json_encode([
        'success' => false,
        'message' => 'Please specify a theme, labels, or both'
    ]);
    exit;
}

// Ensure labels is an array even if empty
if (!is_array($labels)) {
    $labels = [];
}

// Create a unique filename for the ZIP including labels
$timestamp = date('YmdHis');
$filenameParts = [];

if (!empty($thema)) {
    $filenameParts[] = preg_replace('/[^a-zA-Z0-9]/', '_', $thema);
}

if (!empty($labels)) {
    $labelsString = implode('_', array_map(function($label) {
        return preg_replace('/[^a-zA-Z0-9]/', '', $label);
    }, $labels));
    $filenameParts[] = $labelsString;
}

$zipFileName = implode('_', $filenameParts) . '_' . $timestamp . '.zip';
$zipFilePath = $zipDir . '/' . $zipFileName;

// Fetch data from database
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Build query joining form_data with latest matched_transcriptions by ID
    $sql = "SELECT f.id, f.glos, f.thema, f.labels, m.m_file as video_file 
            FROM form_data f 
            INNER JOIN (
                SELECT definitive_outcome, m_file, time,
                       ROW_NUMBER() OVER (PARTITION BY definitive_outcome ORDER BY time DESC) as rn
                FROM matched_transcriptions 
                WHERE m_file IS NOT NULL AND m_file != ''
            ) m ON f.id = m.definitive_outcome AND m.rn = 1";
    $params = [];
    
    // Add theme filter if specified
    if (!empty($thema)) {
        $sql .= " AND f.thema = :thema";
        $params[':thema'] = $thema;
    }
    
    // Add label filter if specified
    if (!empty($labels)) {
        $labelConditions = [];
        foreach ($labels as $index => $label) {
            $paramName = ":label$index";
            $labelConditions[] = "f.labels LIKE $paramName";
            $params[$paramName] = '%"' . $label . '"%';
        }
        if (!empty($labelConditions)) {
            // Use AND to require ALL selected labels
            $sql .= " AND (" . implode(' AND ', $labelConditions) . ")";
        }
    }
    
    $sql .= " ORDER BY glos LIMIT 10000";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convert to the same format as the old API
    $data = ['data' => $results];
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
    exit;
}

// Enhanced validation to check for actual video data
if (!isset($data['data']) || empty($data['data'])) {
    echo json_encode([
        'success' => false,
        'message' => 'No videos found for the selected criteria',
        'data' => $data
    ]);
    exit;
}

// Validate if we have any entries with actual video files
$hasVideos = false;
foreach ($data['data'] as $item) {
    if (!empty($item['video_file'])) {
        $hasVideos = true;
        break;
    }
}

if (!$hasVideos) {
    echo json_encode([
        'success' => false,
        'message' => 'No video files found for the selected criteria',
        'data' => $data
    ]);
    exit;
}

// Create a new ZIP archive
$zip = new ZipArchive();
if ($zip->open($zipFilePath, ZipArchive::CREATE) !== true) {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to create ZIP file'
    ]);
    exit;
}

$successCount = 0;
$errorCount = 0;
$debugInfo = [
    'processedFiles' => [],
    'errors' => [],
    'filterInfo' => [
        'thema' => $thema,
        'labels' => $labels,
        'totalItems' => 0,
        'itemsAfterLabelFilter' => 0
    ]
];

// Process results to add video information and create data array
$processedData = [];
foreach ($results as $result) {
    if (!empty($result['video_file'])) {
        // Convert .wav to .mp4
        $videoFile = str_replace('.wav', '.mp4', $result['video_file']);
        $result['videoCenter'] = json_encode([['file' => $videoFile]]);
    } else {
        $result['videoCenter'] = null;
    }
    $processedData[] = $result;
}

// Convert to the same format as the old API
$data = ['data' => $processedData];

// Process each item in the data array
$debugInfo['filterInfo']['totalItems'] = count($data['data']);

foreach ($data['data'] as $item) {
    $glos = $item['glos'];
    $videoFile = null;
    
    // Get video file from the matched_transcriptions data
    if (!empty($item['video_file'])) {
        $videoFile = str_replace('.wav', '.mp4', $item['video_file']);
    }
    
    // Since we're filtering in the database query, all items here already match the criteria
    // But let's keep some debug info
    if (!empty($item['labels'])) {
        $itemLabels = json_decode($item['labels'], true);
        if (is_array($itemLabels)) {
            $debugInfo['errors'][] = "Processing $glos with labels: " . json_encode($itemLabels);
        }
    }
    
    $debugInfo['filterInfo']['itemsAfterLabelFilter']++;
    
    // Skip if no video file available
    if (empty($videoFile)) {
        $debugInfo['errors'][] = "No video file for: " . $glos;
        continue;
    }
    
    // Full path to the video file
    $videoPath = sc_dir('media_post') . $videoFile;

    
    // Check if the file exists
    if (file_exists($videoPath)) {
        // Use the glos name directly as the filename with mp4 extension
        $sanitizedGlos = preg_replace('/[^a-zA-Z0-9\-]/', '_', $glos);
        $zipEntryName = $sanitizedGlos . '.mp4';
        
        // Add the file to the ZIP
        if ($zip->addFile($videoPath, $zipEntryName)) {
            $successCount++;
            $debugInfo['processedFiles'][] = [
                'glos' => $glos,
                'videoFile' => $videoFile,
                'videoPath' => $videoPath,
                'zipEntryName' => $zipEntryName
            ];
        } else {
            $errorCount++;
            $debugInfo['errors'][] = "Failed to add to ZIP: " . $videoPath;
        }
    } else {
        $errorCount++;
        $debugInfo['errors'][] = "File not found: " . $videoPath;
    }
}

// Close the ZIP file
$zip->close();

// Check if any videos were added
if ($successCount == 0) {
    // No videos were added, delete the empty ZIP file
    if (file_exists($zipFilePath)) {
        unlink($zipFilePath);
    }
    
    echo json_encode([
        'success' => false,
        'message' => 'No valid videos found for this theme',
        'data' => $data,
        'debug' => $debugInfo
    ]);
    exit;
}

// Return success response with the ZIP file URL
echo json_encode([
    'success' => true,
    'zipFile' => 'zipFiles/' . $zipFileName,
    'count' => $successCount,
    'errors' => $errorCount,
    'debug' => $debugInfo
]);
?>
