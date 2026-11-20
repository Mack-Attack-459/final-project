<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    $user = signed_in_user();
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $result = $user;
        if ($user['role'] === 'Artist') {
            $statement = db()->prepare('SELECT display_name, biography, art_medium, profile_photo_url FROM Artist WHERE account_id = ?');
            $statement->bind_param('i', $user['account_id']);
            $statement->execute();
            $result['profile'] = $statement->get_result()->fetch_assoc();
        } else {
            $statement = db()->prepare('SELECT phone_number FROM Customer WHERE account_id = ?');
            $statement->bind_param('i', $user['account_id']);
            $statement->execute();
            $result['profile'] = $statement->get_result()->fetch_assoc();
        }
        respond(['user' => $result]);
    }

    require_method('POST');
    $data = read_json();
    $first = trim((string)($data['firstName'] ?? $user['first_name']));
    $last = trim((string)($data['lastName'] ?? $user['last_name']));
    $email = strtolower(trim((string)($data['email'] ?? $user['email'])));
    if ($first === '' || $last === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) respond(['error' => 'Enter a first name, last name, and valid email.'], 422);
    $connection = db();
    $connection->begin_transaction();
    try {
        $account = $connection->prepare('UPDATE Account SET first_name = ?, last_name = ?, email = ? WHERE account_id = ?');
        $account->bind_param('sssi', $first, $last, $email, $user['account_id']);
        $account->execute();
        if ($user['role'] === 'Artist') {
            $display = trim((string)($data['displayName'] ?? ($first . ' ' . $last)));
            $bio = trim((string)($data['biography'] ?? ''));
            $medium = trim((string)($data['medium'] ?? ''));
            $photo = trim((string)($data['photoUrl'] ?? ''));
            if ($display === '' || $bio === '' || $medium === '' || ($photo !== '' && !filter_var($photo, FILTER_VALIDATE_URL))) respond(['error' => 'Complete the artist name, biography, medium, and use a valid photo URL.'], 422);
            $statement = $connection->prepare('UPDATE Artist SET display_name = ?, biography = ?, art_medium = ?, profile_photo_url = ? WHERE account_id = ?');
            $statement->bind_param('ssssi', $display, $bio, $medium, $photo, $user['account_id']);
            $statement->execute();
        } elseif ($user['role'] === 'Customer') {
            $phone = trim((string)($data['phone'] ?? ''));
            $statement = $connection->prepare('UPDATE Customer SET phone_number = ? WHERE account_id = ?');
            $statement->bind_param('si', $phone, $user['account_id']);
            $statement->execute();
        }
        $connection->commit();
    } catch (Throwable $error) {
        $connection->rollback();
        throw $error;
    }
    respond(['ok' => true]);
} catch (Throwable $error) {
    handle_api_error($error);
}
