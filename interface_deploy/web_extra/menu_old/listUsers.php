<?php
// Assuming connection setup is correct
include('/web/mysql_config.php');
$conn = new mysqli($servername, $username, $password, $database);

$query = "SELECT userid, user, lang FROM users";
$result = $conn->query($query);

$users = [];

while($row = $result->fetch_assoc()) {
    $users[] = [
        'userid' => $row['userid'],
        'user' => $row['user'],
        'lang' => $row['lang']
    ];
}

header('Content-Type: application/json');
echo json_encode($users);
?>
