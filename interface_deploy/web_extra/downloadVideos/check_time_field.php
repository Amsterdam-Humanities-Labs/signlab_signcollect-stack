<?php
require_once('../mysql_config.php');

header('Content-Type: text/plain');

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check the structure of matched_transcriptions table
    echo "=== Matched_transcriptions table structure ===\n";
    $sql = "DESCRIBE matched_transcriptions";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($columns as $column) {
        echo $column['Field'] . " - " . $column['Type'] . "\n";
    }
    
    // Check sample entries for ID 46108 (AANDACHT-B) to see the time field
    echo "\n=== Sample entries for ID 46108 (AANDACHT-B) ===\n";
    $sql2 = "SELECT definitive_outcome, m_file, time FROM matched_transcriptions WHERE definitive_outcome = '46108' ORDER BY time DESC";
    $stmt2 = $pdo->prepare($sql2);
    $stmt2->execute();
    $samples = $stmt2->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($samples as $sample) {
        echo "Outcome: " . $sample['definitive_outcome'] . " | File: " . $sample['m_file'] . " | Time: " . $sample['time'] . "\n";
    }
    
    // Test a query that gets only the latest entry per form_data ID
    echo "\n=== Testing latest entry query ===\n";
    $sql3 = "SELECT f.id, f.glos, f.thema, f.labels, m.m_file as video_file, m.time
            FROM form_data f 
            INNER JOIN (
                SELECT definitive_outcome, m_file, time,
                       ROW_NUMBER() OVER (PARTITION BY definitive_outcome ORDER BY time DESC) as rn
                FROM matched_transcriptions 
                WHERE m_file IS NOT NULL AND m_file != ''
            ) m ON f.id = m.definitive_outcome AND m.rn = 1
            WHERE f.labels LIKE '%\"1500Gebaren\"%'
            ORDER BY f.glos
            LIMIT 10";
    
    $stmt3 = $pdo->prepare($sql3);
    $stmt3->execute();
    $results = $stmt3->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($results) . " unique entries:\n";
    foreach ($results as $result) {
        echo "- " . $result['glos'] . " | File: " . $result['video_file'] . " | Time: " . $result['time'] . "\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>