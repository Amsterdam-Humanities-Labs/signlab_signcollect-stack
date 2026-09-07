<?php
require_once('../mysql_config.php');

header('Content-Type: application/json');

// Get parameters
$thema = isset($_GET['thema']) ? $_GET['thema'] : '';
$labels = isset($_GET['labels']) ? json_decode($_GET['labels'], true) : [];

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Build base query joining form_data with latest matched_transcriptions by ID
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
    
    $sql .= " ORDER BY glos";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // If no results, check if there are entries with labels but no videos
    if (empty($results) && !empty($labels)) {
        $checkSql = "SELECT COUNT(*) as label_count FROM form_data f WHERE ";
        $checkParams = [];
        
        $labelConditions = [];
        foreach ($labels as $index => $label) {
            $paramName = ":label$index";
            $labelConditions[] = "f.labels LIKE $paramName";
            $checkParams[$paramName] = '%"' . $label . '"%';
        }
        
        if (!empty($labelConditions)) {
            $checkSql .= "(" . implode(' AND ', $labelConditions) . ")";
        }
        
        $checkStmt = $pdo->prepare($checkSql);
        $checkStmt->execute($checkParams);
        $labelCount = $checkStmt->fetch(PDO::FETCH_ASSOC)['label_count'];
        
        if ($labelCount > 0) {
            echo json_encode([
                'success' => false,
                'message' => "Found $labelCount entries with selected labels, but none have matching video files available.",
                'label_count' => $labelCount,
                'data' => [],
                'query' => $sql,
                'params' => $params
            ]);
            return;
        }
    }
    
    // Process results to add video information
    foreach ($results as &$result) {
        if (!empty($result['video_file'])) {
            // Convert .wav to .mp4
            $videoFile = str_replace('.wav', '.mp4', $result['video_file']);
            $result['videoCenter'] = json_encode([['file' => $videoFile]]);
            $result['video_path'] = '/web/gebarenoverleg_media/studioFilesMini/post/' . $videoFile;
        } else {
            $result['videoCenter'] = null;
            $result['video_path'] = null;
        }
    }
    
    echo json_encode([
        'success' => true,
        'data' => $results,
        'count' => count($results),
        'query' => $sql,
        'params' => $params
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
        'query' => $sql ?? 'No query built',
        'params' => $params ?? []
    ]);
}
?>