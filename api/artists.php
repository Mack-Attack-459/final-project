<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    require_method('GET');
    $query = 'SELECT ar.artist_id AS id, ar.account_id AS accountId, ar.display_name AS displayName, ar.biography, ar.art_medium AS medium, ar.profile_photo_url AS photoUrl, COUNT(w.artwork_id) AS artworkCount FROM Artist ar LEFT JOIN Artwork w ON w.artist_id = ar.artist_id GROUP BY ar.artist_id ORDER BY ar.display_name';
    $result = db()->query($query);
    respond(['artists' => $result->fetch_all(MYSQLI_ASSOC)]);
} catch (Throwable $error) {
    handle_api_error($error);
}
