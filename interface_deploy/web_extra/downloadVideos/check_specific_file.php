<?php
require_once('../mysql_config.php');

header('Content-Type: text/plain');

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "=== Checking for file M20250331_6564.wav ===\n\n";
    
    // Check if this file exists in matched_transcriptions
    $sql1 = "SELECT * FROM matched_transcriptions WHERE m_file = 'M20250331_6564.wav'";
    $stmt1 = $pdo->prepare($sql1);
    $stmt1->execute();
    $file_matches = $stmt1->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($file_matches)) {
        echo "Found " . count($file_matches) . " entries with file M20250331_6564.wav:\n";
        foreach ($file_matches as $match) {
            echo "- Outcome: '" . $match['definitive_outcome'] . "' -> File: " . $match['m_file'] . "\n";
        }
    } else {
        echo "No entries found with file M20250331_6564.wav\n";
    }
    
    // Check if AANDACHT-B exists with any file
    echo "\n=== Checking for AANDACHT-B in matched_transcriptions ===\n";
    $sql2 = "SELECT * FROM matched_transcriptions WHERE definitive_outcome = 'AANDACHT-B'";
    $stmt2 = $pdo->prepare($sql2);
    $stmt2->execute();
    $aandacht_matches = $stmt2->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($aandacht_matches)) {
        echo "Found " . count($aandacht_matches) . " entries for AANDACHT-B:\n";
        foreach ($aandacht_matches as $match) {
            echo "- Outcome: '" . $match['definitive_outcome'] . "' -> File: " . ($match['m_file'] ?? 'NULL') . "\n";
        }
    } else {
        echo "No entries found for AANDACHT-B\n";
    }
    
    // Let's also check what glos values from 1500Gebaren entries exist in matched_transcriptions
    echo "\n=== Checking which 1500Gebaren glos values exist in matched_transcriptions ===\n";
    
    $sql3 = "SELECT DISTINCT f.glos 
            FROM form_data f 
            INNER JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
            WHERE f.labels LIKE '%\"1500Gebaren\"%' 
            AND m.m_file IS NOT NULL 
            AND m.m_file != ''
            LIMIT 10";
    
    $stmt3 = $pdo->prepare($sql3);
    $stmt3->execute();
    $working_glos = $stmt3->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($working_glos)) {
        echo "Found " . count($working_glos) . " 1500Gebaren glos values that DO have video matches:\n";
        foreach ($working_glos as $glos) {
            echo "- " . $glos['glos'] . "\n";
        }
    } else {
        echo "No 1500Gebaren glos values have video matches\n";
    }
    
    // Let's check a few sample 1500Gebaren entries to see their glos values
    echo "\n=== Sample 1500Gebaren entries and their glos values ===\n";
    $sql4 = "SELECT id, glos, labels FROM form_data WHERE labels LIKE '%\"1500Gebaren\"%' LIMIT 10";
    $stmt4 = $pdo->prepare($sql4);
    $stmt4->execute();
    $sample_entries = $stmt4->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($sample_entries as $entry) {
        echo "ID: " . $entry['id'] . " - Glos: '" . $entry['glos'] . "'\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>