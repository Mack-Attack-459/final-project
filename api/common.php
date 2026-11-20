<?php
declare(strict_types=1);

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function start_app_session(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) return;
    ini_set('session.use_strict_mode', '1');
    session_set_cookie_params([
        'httponly' => true,
        'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
        'samesite' => 'Lax',
        'path' => '/',
    ]);
    session_start();
}

function db(): mysqli
{
    static $connection = null;
    if ($connection instanceof mysqli) return $connection;

    $host = getenv('CAE_DB_HOST') ?: '127.0.0.1';
    $port = (int)(getenv('CAE_DB_PORT') ?: '8889');
    $user = getenv('CAE_DB_USER') ?: 'root';
    $pass = getenv('CAE_DB_PASS') ?: 'root';
    $name = getenv('CAE_DB_NAME') ?: 'campus_artwork_exhibit';

    $connection = new mysqli($host, $user, $pass, $name, $port);
    $connection->set_charset('utf8mb4');
    return $connection;
}

function respond(array $payload, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function read_json(): array
{
    $body = file_get_contents('php://input');
    $data = json_decode($body ?: '{}', true);
    if (!is_array($data)) respond(['error' => 'Request body must be valid JSON.'], 400);
    return $data;
}

function require_method(string $expected): void
{
    if (strtoupper($_SERVER['REQUEST_METHOD'] ?? '') !== strtoupper($expected)) {
        header('Allow: ' . strtoupper($expected));
        respond(['error' => 'Method not allowed.'], 405);
    }
}

function signed_in_user(bool $required = true): ?array
{
    start_app_session();
    $id = $_SESSION['account_id'] ?? null;
    if (!$id) {
        if ($required) respond(['error' => 'Please sign in first.'], 401);
        return null;
    }
    $statement = db()->prepare('SELECT account_id, first_name, last_name, email, role FROM Account WHERE account_id = ? AND account_status = \'Active\'');
    $statement->bind_param('i', $id);
    $statement->execute();
    $user = $statement->get_result()->fetch_assoc();
    if (!$user) {
        session_destroy();
        if ($required) respond(['error' => 'Your account is no longer active.'], 401);
        return null;
    }
    return $user;
}

function require_role(string $role): array
{
    $user = signed_in_user();
    if ($user['role'] !== $role) respond(['error' => 'You do not have permission to do that.'], 403);
    return $user;
}

function handle_api_error(Throwable $error): void
{
    error_log('Campus Artwork Exhibit API: ' . $error->getMessage());
    respond(['error' => 'The request could not be completed. Check that MySQL is running and the database has been imported.'], 500);
}

start_app_session();
