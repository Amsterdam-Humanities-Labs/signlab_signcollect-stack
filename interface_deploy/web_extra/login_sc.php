<?php

include('mysql_config.php');


// Create connection
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get username and password from the POST request
$username = $_POST['username'];
$password = $_POST['password'];

// Use prepared statements to prevent SQL injection
$stmt = $conn->prepare("SELECT userId, user, blocked, last_login, last_activity, role FROM users WHERE user = ? AND pass = ?");
$stmt->bind_param("ss", $username, $password);

$stmt->execute();
$stmt->bind_result($userId, $resultUsername, $blocked, $lastLogin, $lastActivity, $role);

// Check if the user exists
if ($stmt->fetch()) {
    // Check if user is explicitly blocked
    if ($blocked == 1) {
        echo json_encode(array('status' => 'blocked'));
        $stmt->close();
        $conn->close();
        exit;
    }

    // Auto-block on 60-day inactivity. last_login only updates on a fresh
    // password login, so use whichever of last_login / last_activity is
    // newer — otherwise a user who keeps a cookie session alive for
    // months gets blocked next time they re-enter their password.
    $mostRecent = null;
    if ($lastActivity !== null) $mostRecent = $lastActivity;
    if ($lastLogin !== null && ($mostRecent === null || $lastLogin > $mostRecent)) $mostRecent = $lastLogin;
    if ($mostRecent !== null) {
        $diff = (new DateTime())->diff(new DateTime($mostRecent));
        if ($diff->days > 60) {
            $stmt->close();
            $blockStmt = $conn->prepare("UPDATE users SET blocked = 1 WHERE userId = ?");
            $blockStmt->bind_param("i", $userId);
            $blockStmt->execute();
            $blockStmt->close();
            echo json_encode(array('status' => 'blocked'));
            $conn->close();
            exit;
        }
    }

    // Login successful - update last_login
    $stmt->close();
    $updateStmt = $conn->prepare("UPDATE users SET last_login = NOW() WHERE userId = ?");
    $updateStmt->bind_param("i", $userId);
    $updateStmt->execute();
    $updateStmt->close();

    echo json_encode(array('status' => 'success', 'userId' => $userId, 'username' => $resultUsername, 'role' => $role));
} else {
    // Login failed
    $stmt->close();
    echo json_encode(array('status' => 'failure'));
}

$conn->close();

?>
