<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $user = signed_in_user(false);
        if (!$user) respond(['user' => null]);
        $user['profile'] = null;
        if ($user['role'] === 'Artist') {
            $statement = db()->prepare('SELECT display_name, biography, art_medium, profile_photo_url FROM Artist WHERE account_id = ?');
            $statement->bind_param('i', $user['account_id']);
            $statement->execute();
            $user['profile'] = $statement->get_result()->fetch_assoc();
        } elseif ($user['role'] === 'Customer') {
            $statement = db()->prepare('SELECT phone_number FROM Customer WHERE account_id = ?');
            $statement->bind_param('i', $user['account_id']);
            $statement->execute();
            $user['profile'] = $statement->get_result()->fetch_assoc();
        }
        respond(['user' => $user]);
    }

    require_method('POST');
    $data = read_json();
    $action = (string)($data['action'] ?? '');

    if ($action === 'signout') {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'] ?? '', $params['secure'], $params['httponly']);
        }
        session_destroy();
        respond(['ok' => true]);
    }

    if ($action === 'signup') {
        $first = trim((string)($data['firstName'] ?? ''));
        $last = trim((string)($data['lastName'] ?? ''));
        $email = strtolower(trim((string)($data['email'] ?? '')));
        $password = (string)($data['password'] ?? '');
        $role = (string)($data['role'] ?? '');
        if ($first === '' || $last === '' || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8 || !in_array($role, ['Artist', 'Customer'], true)) {
            respond(['error' => 'Enter your name, a valid email, a password with at least 8 characters, and an account type.'], 422);
        }
        $connection = db();
        $connection->begin_transaction();
        try {
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $statement = $connection->prepare('INSERT INTO Account (first_name, last_name, email, password_hash, role) VALUES (?, ?, ?, ?, ?)');
            $statement->bind_param('sssss', $first, $last, $email, $hash, $role);
            $statement->execute();
            $accountId = $connection->insert_id;
            if ($role === 'Artist') {
                $displayName = $first . ' ' . $last;
                $bio = 'Tell visitors about your work and creative practice.';
                $medium = 'Mixed media';
                $profile = $connection->prepare('INSERT INTO Artist (account_id, display_name, biography, art_medium) VALUES (?, ?, ?, ?)');
                $profile->bind_param('isss', $accountId, $displayName, $bio, $medium);
            } else {
                $profile = $connection->prepare('INSERT INTO Customer (account_id) VALUES (?)');
                $profile->bind_param('i', $accountId);
            }
            $profile->execute();
            $connection->commit();
            session_regenerate_id(true);
            $_SESSION['account_id'] = $accountId;
            respond(['ok' => true, 'user' => ['account_id' => $accountId, 'first_name' => $first, 'last_name' => $last, 'email' => $email, 'role' => $role]]);
        } catch (Throwable $error) {
            $connection->rollback();
            throw $error;
        }
    }

    if ($action === 'signin') {
        $email = strtolower(trim((string)($data['email'] ?? '')));
        $password = (string)($data['password'] ?? '');
        $statement = db()->prepare('SELECT account_id, first_name, last_name, email, password_hash, role FROM Account WHERE email = ? AND account_status = \'Active\'');
        $statement->bind_param('s', $email);
        $statement->execute();
        $user = $statement->get_result()->fetch_assoc();
        $verified = $user && password_verify($password, $user['password_hash']);
        // The Milestone 2 seed rows use MySQL SHA2; migrate a matching demo account to PHP's password hash on first login.
        $seedHashMatch = $user && preg_match('/^[a-f0-9]{64}$/i', $user['password_hash']) && hash_equals(strtolower($user['password_hash']), hash('sha256', $password));
        if (!$verified && !$seedHashMatch) respond(['error' => 'Email or password is incorrect.'], 401);
        if ($seedHashMatch) {
            $newHash = password_hash($password, PASSWORD_DEFAULT);
            $upgrade = db()->prepare('UPDATE Account SET password_hash = ? WHERE account_id = ?');
            $upgrade->bind_param('si', $newHash, $user['account_id']);
            $upgrade->execute();
        }
        session_regenerate_id(true);
        $_SESSION['account_id'] = (int)$user['account_id'];
        unset($user['password_hash']);
        respond(['ok' => true, 'user' => $user]);
    }

    respond(['error' => 'Unknown account action.'], 400);
} catch (Throwable $error) {
    handle_api_error($error);
}
