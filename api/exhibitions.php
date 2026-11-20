<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    require_method('GET');
    $query = 'SELECT e.exhibition_id AS id, e.exhibition_title AS title, e.description, e.start_date AS startDate, e.end_date AS endDate, e.exhibition_status AS status, l.location_name AS location, l.building_name AS building, l.room_number AS room, COUNT(ea.artwork_id) AS artworkCount FROM Exhibition e JOIN Location l ON l.location_id = e.location_id LEFT JOIN ExhibitionArtwork ea ON ea.exhibition_id = e.exhibition_id GROUP BY e.exhibition_id ORDER BY e.start_date DESC';
    $result = db()->query($query);
    respond(['exhibitions' => $result->fetch_all(MYSQLI_ASSOC)]);
} catch (Throwable $error) {
    handle_api_error($error);
}
