<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check zOg values
    echo "zOg values in matched_transcriptions:\n";
    $stmt = $pdo->query("SELECT DISTINCT zOg, COUNT(*) as count FROM matched_transcriptions GROUP BY zOg");
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($results as $result) {
        echo "- '" . $result['zOg'] . "': " . $result['count'] . " records\n";
    }
    
    // Check if there are any matches between the tables
    echo "\nChecking join between form_data and matched_transcriptions:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM form_data f INNER JOIN matched_transcriptions m ON f.id = m.id");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Total joined records: " . $result['count'] . "\n";
    
    // Check a few records with videos
    echo "\nSample records with m_file:\n";
    $stmt = $pdo->query("SELECT f.id, f.glos, f.labels, m.m_file, m.zOg FROM form_data f INNER JOIN matched_transcriptions m ON f.id = m.id WHERE m.m_file IS NOT NULL AND m.m_file != '' LIMIT 5");
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($results as $result) {
        echo "ID: " . $result['id'] . ", Glos: " . $result['glos'] . ", zOg: " . $result['zOg'] . ", m_file: " . $result['m_file'] . "\n";
        echo "  Labels: " . ($result['labels'] ?? 'NULL') . "\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>