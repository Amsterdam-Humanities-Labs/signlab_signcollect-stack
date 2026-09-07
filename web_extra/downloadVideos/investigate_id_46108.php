<?php
require_once('../mysql_config.php');

header('Content-Type: text/plain');

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "=== Investigating ID 46108 ===\n\n";
    
    // Check the form_data entry
    $sql1 = "SELECT id, glos, thema, labels FROM form_data WHERE id = 46108";
    $stmt1 = $pdo->prepare($sql1);
    $stmt1->execute();
    $form_data = $stmt1->fetch(PDO::FETCH_ASSOC);
    
    if ($form_data) {
        echo "Form Data Entry:\n";
        echo "ID: " . $form_data['id'] . "\n";
        echo "Glos: '" . $form_data['glos'] . "'\n";
        echo "Thema: " . $form_data['thema'] . "\n";
        echo "Labels: " . $form_data['labels'] . "\n\n";
        
        // Now check if there's a matching entry in matched_transcriptions
        $glos = $form_data['glos'];
        echo "=== Checking matched_transcriptions for glos: '$glos' ===\n";
        
        $sql2 = "SELECT definitive_outcome, m_file FROM matched_transcriptions WHERE definitive_outcome = :glos";
        $stmt2 = $pdo->prepare($sql2);
        $stmt2->execute([':glos' => $glos]);
        $matches = $stmt2->fetchAll(PDO::FETCH_ASSOC);
        
        if (!empty($matches)) {
            echo "Found " . count($matches) . " matches:\n";
            foreach ($matches as $match) {
                echo "- Outcome: '" . $match['definitive_outcome'] . "' -> File: " . $match['m_file'] . "\n";
            }
        } else {
            echo "No matches found for glos: '$glos'\n";
            
            // Let's see what similar glos values exist
            echo "\n=== Checking similar glos values ===\n";
            $sql3 = "SELECT DISTINCT definitive_outcome FROM matched_transcriptions WHERE definitive_outcome LIKE :glos_pattern LIMIT 10";
            $stmt3 = $pdo->prepare($sql3);
            $stmt3->execute([':glos_pattern' => '%' . $glos . '%']);
            $similar = $stmt3->fetchAll(PDO::FETCH_ASSOC);
            
            if (!empty($similar)) {
                echo "Similar definitive_outcomes:\n";
                foreach ($similar as $sim) {
                    echo "- '" . $sim['definitive_outcome'] . "'\n";
                }
            } else {
                echo "No similar definitive_outcomes found\n";
            }
        }
        
        // Let's also check if there are any matches with this exact glos anywhere
        echo "\n=== Checking ALL matched_transcriptions for exact glos match ===\n";
        $sql4 = "SELECT definitive_outcome, m_file FROM matched_transcriptions WHERE definitive_outcome = :glos AND m_file IS NOT NULL AND m_file != ''";
        $stmt4 = $pdo->prepare($sql4);
        $stmt4->execute([':glos' => $glos]);
        $exact_matches = $stmt4->fetchAll(PDO::FETCH_ASSOC);
        
        if (!empty($exact_matches)) {
            echo "Found " . count($exact_matches) . " exact matches with video files:\n";
            foreach ($exact_matches as $match) {
                echo "- Outcome: '" . $match['definitive_outcome'] . "' -> File: " . $match['m_file'] . "\n";
            }
        } else {
            echo "No exact matches with video files found\n";
        }
        
    } else {
        echo "No form_data entry found for ID 46108\n";
    }
    
    // Also check if there are any entries with 1500Gebaren that DO have matches
    echo "\n\n=== Checking other 1500Gebaren entries for matches ===\n";
    $sql5 = "SELECT f.id, f.glos, f.labels, m.m_file 
            FROM form_data f 
            LEFT JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
            WHERE f.labels LIKE '%\"1500Gebaren\"%' 
            AND m.m_file IS NOT NULL 
            AND m.m_file != ''
            LIMIT 5";
    
    $stmt5 = $pdo->prepare($sql5);
    $stmt5->execute();
    $matches_with_videos = $stmt5->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($matches_with_videos)) {
        echo "Found " . count($matches_with_videos) . " 1500Gebaren entries with videos:\n";
        foreach ($matches_with_videos as $match) {
            echo "- ID: " . $match['id'] . ", Glos: '" . $match['glos'] . "', File: " . $match['m_file'] . "\n";
        }
    } else {
        echo "No 1500Gebaren entries with videos found\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>