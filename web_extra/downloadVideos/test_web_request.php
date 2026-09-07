<?php
// Simulate web request for 1500Gebaren label
$_GET['labels'] = '["1500Gebaren"]';

// Include the fetch script
include 'fetch_videos_with_labels.php';
?>