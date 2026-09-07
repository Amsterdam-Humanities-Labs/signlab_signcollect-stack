<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check records with labels and videos
    echo "Looking for records with both labels and video files:\n";
    $stmt = $pdo->query("SELECT f.id, f.glos, f.labels, m.m_file, m.zOg 
                         FROM form_data f 
                         INNER JOIN matched_transcriptions m ON f.id = m.id 
                         WHERE f.labels IS NOT NULL AND f.labels != '' AND f.labels != '[]'
                         AND m.m_file IS NOT NULL AND m.m_file != ''
                         LIMIT 10");
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($results)) {
        echo "No records found with both labels and video files!\n";
        
        // Check records with labels (regardless of video)
        echo "\nRecords with labels (no video requirement):\n";
        $stmt = $pdo->query("SELECT id, glos, labels FROM form_data WHERE labels IS NOT NULL AND labels != '' AND labels != '[]' LIMIT 5");
        $labelResults = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($labelResults as $result) {
            echo "ID: " . $result['id'] . ", Glos: " . $result['glos'] . ", Labels: " . $result['labels'] . "\n";
        }
        
        // Check records with videos (regardless of labels)
        echo "\nRecords with video files (no label requirement):\n";
        $stmt = $pdo->query("SELECT f.id, f.glos, m.m_file, m.zOg FROM form_data f INNER JOIN matched_transcriptions m ON f.id = m.id WHERE m.m_file IS NOT NULL AND m.m_file != '' LIMIT 5");
        $videoResults = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($videoResults as $result) {
            echo "ID: " . $result['id'] . ", Glos: " . $result['glos'] . ", Video: " . $result['m_file'] . ", zOg: " . $result['zOg'] . "\n";
        }
        
    } else {
        foreach ($results as $result) {
            echo "ID: " . $result['id'] . ", Glos: " . $result['glos'] . ", Video: " . $result['m_file'] . ", zOg: " . $result['zOg'] . "\n";
            echo "  Labels: " . $result['labels'] . "\n";
        }
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>