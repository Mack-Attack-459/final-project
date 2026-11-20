<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $query = 'SELECT w.artwork_id AS id, w.artist_id, w.title, w.description, w.medium, w.creation_year AS year, w.image_url AS imageUrl, w.asking_price AS price, w.availability_status AS availability, ar.display_name AS artistName, ar.account_id AS ownerId FROM Artwork w JOIN Artist ar ON ar.artist_id = w.artist_id';
        if (isset($_GET['id'])) {
            $id = filter_var($_GET['id'], FILTER_VALIDATE_INT);
            if (!$id) respond(['error' => 'Artwork ID is invalid.'], 400);
            $statement = db()->prepare($query . ' WHERE w.artwork_id = ?');
            $statement->bind_param('i', $id);
            $statement->execute();
            $item = $statement->get_result()->fetch_assoc();
            if (!$item) respond(['error' => 'Artwork was not found.'], 404);
            respond(['artwork' => $item]);
        }
        if (($_GET['mine'] ?? '') === '1') {
            $user = require_role('Artist');
            $query .= ' WHERE ar.account_id = ?';
            $statement = db()->prepare($query . ' ORDER BY w.artwork_id DESC');
            $statement->bind_param('i', $user['account_id']);
        } else {
            $statement = db()->prepare($query . ' ORDER BY w.artwork_id DESC');
        }
        $statement->execute();
        respond(['artworks' => $statement->get_result()->fetch_all(MYSQLI_ASSOC)]);
    }

    require_method('POST');
    $user = require_role('Artist');
    $data = read_json();
    $title = trim((string)($data['title'] ?? ''));
    $description = trim((string)($data['description'] ?? ''));
    $medium = trim((string)($data['medium'] ?? ''));
    $image = trim((string)($data['imageUrl'] ?? ''));
    $year = filter_var($data['year'] ?? null, FILTER_VALIDATE_INT);
    $availability = (string)($data['availability'] ?? 'Available');
    $priceText = trim((string)($data['price'] ?? ''));
    $price = $priceText === '' ? null : filter_var($priceText, FILTER_VALIDATE_FLOAT);
    if ($title === '' || $description === '' || $medium === '' || !filter_var($image, FILTER_VALIDATE_URL) || !$year || $year < 1901 || $year > 2155 || !in_array($availability, ['Available', 'Not for Sale'], true) || ($priceText !== '' && ($price === false || $price < 0))) {
        respond(['error' => 'Enter a title, description, medium, valid image URL, year, and valid price.'], 422);
    }
    $statement = db()->prepare('SELECT artist_id FROM Artist WHERE account_id = ?');
    $statement->bind_param('i', $user['account_id']);
    $statement->execute();
    $artist = $statement->get_result()->fetch_assoc();
    if (!$artist) respond(['error' => 'Artist profile was not found.'], 409);
    $statement = db()->prepare('INSERT INTO Artwork (artist_id, title, description, medium, creation_year, image_url, asking_price, availability_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $statement->bind_param('isssisss', $artist['artist_id'], $title, $description, $medium, $year, $image, $price, $availability);
    $statement->execute();
    respond(['ok' => true, 'id' => db()->insert_id], 201);
} catch (Throwable $error) {
    handle_api_error($error);
}
