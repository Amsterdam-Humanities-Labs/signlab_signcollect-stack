<?php
// Simulate POST request for 1500Gebaren download
$_POST['labels'] = '["1500Gebaren"]';

echo "Testing 1500Gebaren download...\n\n";

// Include the download script
include 'downloadThemaVideo.php';
?>