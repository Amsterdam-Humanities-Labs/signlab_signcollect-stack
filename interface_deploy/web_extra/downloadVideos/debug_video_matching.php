<?php
require_once('../mysql_config.php');

header('Content-Type: text/plain');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check some 1500Gebaren entries and see if they have video matches
    $sql = "SELECT f.glos, f.labels, m.m_file, m.definitive_outcome 
            FROM form_data f 
            LEFT JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
            WHERE f.labels LIKE '%\"1500Gebaren\"%' 
            LIMIT 10";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Checking video matching for 1500Gebaren entries:\n";
    echo "====================================================\n";
    
    foreach ($results as $result) {
        echo "Glos: " . $result['glos'] . "\n";
        echo "Labels: " . $result['labels'] . "\n";
        echo "Video file: " . ($result['m_file'] ?? 'NULL') . "\n";
        echo "Matched outcome: " . ($result['definitive_outcome'] ?? 'NULL') . "\n";
        echo "---\n";
    }
    
    // Check if there are any entries in matched_transcriptions at all
    echo "\n\nChecking matched_transcriptions table:\n";
    echo "=====================================\n";
    
    $sql2 = "SELECT COUNT(*) as total_matches FROM matched_transcriptions WHERE m_file IS NOT NULL AND m_file != ''";
    $stmt2 = $pdo->prepare($sql2);
    $stmt2->execute();
    $total_matches = $stmt2->fetch(PDO::FETCH_ASSOC);
    
    echo "Total video matches in matched_transcriptions: " . $total_matches['total_matches'] . "\n";
    
    // Check some sample matches
    $sql3 = "SELECT definitive_outcome, m_file FROM matched_transcriptions WHERE m_file IS NOT NULL AND m_file != '' LIMIT 5";
    $stmt3 = $pdo->prepare($sql3);
    $stmt3->execute();
    $samples = $stmt3->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Sample matches:\n";
    foreach ($samples as $sample) {
        echo "- " . $sample['definitive_outcome'] . " -> " . $sample['m_file'] . "\n";
    }
    
    // Check if any of our 1500Gebaren glos values appear in matched_transcriptions
    echo "\n\nChecking if 1500Gebaren glos values exist in matched_transcriptions:\n";
    echo "===================================================================\n";
    
    $sql4 = "SELECT f.glos, COUNT(m.definitive_outcome) as match_count
            FROM form_data f 
            LEFT JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
            WHERE f.labels LIKE '%\"1500Gebaren\"%' 
            GROUP BY f.glos
            HAVING match_count > 0
            LIMIT 10";
    
    $stmt4 = $pdo->prepare($sql4);
    $stmt4->execute();
    $matches = $stmt4->fetchAll(PDO::FETCH_ASSOC);
    
    echo "1500Gebaren entries with matches: " . count($matches) . "\n";
    foreach ($matches as $match) {
        echo "- " . $match['glos'] . " (matches: " . $match['match_count'] . ")\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>