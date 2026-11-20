<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    require_method('GET');
    $user = require_role('Customer');
    $statement = db()->prepare("SELECT s.sale_id AS id, s.sale_date AS saleDate, s.sale_amount AS amount, s.sale_status AS status, w.title AS artworkTitle, w.image_url AS imageUrl, ar.display_name AS artistName FROM Sale s JOIN Customer c ON c.customer_id = s.customer_id JOIN Artwork w ON w.artwork_id = s.artwork_id JOIN Artist ar ON ar.artist_id = w.artist_id WHERE c.account_id = ? ORDER BY s.sale_date DESC");
    $statement->bind_param('i', $user['account_id']);
    $statement->execute();
    respond(['purchases' => $statement->get_result()->fetch_all(MYSQLI_ASSOC)]);
} catch (Throwable $error) {
    handle_api_error($error);
}
