<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check ID ranges in both tables
    echo "ID ranges in form_data:\n";
    $stmt = $pdo->query("SELECT MIN(id) as min_id, MAX(id) as max_id, COUNT(*) as total FROM form_data");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Min ID: " . $result['min_id'] . ", Max ID: " . $result['max_id'] . ", Total: " . $result['total'] . "\n";
    
    echo "\nID ranges in matched_transcriptions:\n";
    $stmt = $pdo->query("SELECT MIN(id) as min_id, MAX(id) as max_id, COUNT(*) as total FROM matched_transcriptions");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Min ID: " . $result['min_id'] . ", Max ID: " . $result['max_id'] . ", Total: " . $result['total'] . "\n";
    
    // Check if there's overlap
    echo "\nChecking if there's any overlap in IDs:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as overlap FROM form_data f WHERE EXISTS (SELECT 1 FROM matched_transcriptions m WHERE m.id = f.id)");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Records in form_data that have matching IDs in matched_transcriptions: " . $result['overlap'] . "\n";
    
    // Check if there's a different relationship field
    echo "\nChecking if glos can be used to match:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as glos_match 
                         FROM form_data f 
                         INNER JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
                         WHERE f.labels IS NOT NULL AND f.labels != '' AND f.labels != '[]'
                         AND m.m_file IS NOT NULL AND m.m_file != ''");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Records that can be matched by glos/definitive_outcome: " . $result['glos_match'] . "\n";
    
    if ($result['glos_match'] > 0) {
        echo "\nSample records matched by glos:\n";
        $stmt = $pdo->query("SELECT f.id as form_id, f.glos, f.labels, m.id as match_id, m.m_file, m.definitive_outcome 
                             FROM form_data f 
                             INNER JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
                             WHERE f.labels IS NOT NULL AND f.labels != '' AND f.labels != '[]'
                             AND m.m_file IS NOT NULL AND m.m_file != ''
                             LIMIT 3");
        $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($samples as $sample) {
            echo "Form ID: " . $sample['form_id'] . ", Match ID: " . $sample['match_id'] . "\n";
            echo "  Glos: " . $sample['glos'] . " = " . $sample['definitive_outcome'] . "\n";
            echo "  Labels: " . $sample['labels'] . "\n";
            echo "  Video: " . $sample['m_file'] . "\n\n";
        }
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>