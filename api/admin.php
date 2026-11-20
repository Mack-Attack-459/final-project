<?php
declare(strict_types=1);
require_once __DIR__ . '/common.php';

try {
    $admin = require_role('Administrator');
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $connection = db();
        $locations = $connection->query('SELECT location_id AS id, location_name AS name, building_name AS building, room_number AS room FROM Location ORDER BY location_name')->fetch_all(MYSQLI_ASSOC);
        $exhibitions = $connection->query('SELECT exhibition_id AS id, exhibition_title AS title, exhibition_status AS status FROM Exhibition ORDER BY start_date DESC')->fetch_all(MYSQLI_ASSOC);
        $artworks = $connection->query("SELECT w.artwork_id AS id, w.title, w.asking_price AS price, ar.display_name AS artistName FROM Artwork w JOIN Artist ar ON ar.artist_id = w.artist_id WHERE w.availability_status = 'Available' AND w.asking_price IS NOT NULL ORDER BY w.title")->fetch_all(MYSQLI_ASSOC);
        $displayArtworks = $connection->query("SELECT w.artwork_id AS id, w.title, w.availability_status AS status, ar.display_name AS artistName FROM Artwork w JOIN Artist ar ON ar.artist_id = w.artist_id ORDER BY w.title")->fetch_all(MYSQLI_ASSOC);
        $customers = $connection->query("SELECT c.customer_id AS id, a.first_name AS firstName, a.last_name AS lastName, a.email FROM Customer c JOIN Account a ON a.account_id = c.account_id WHERE a.account_status = 'Active' ORDER BY a.last_name, a.first_name")->fetch_all(MYSQLI_ASSOC);
        respond(['locations' => $locations, 'exhibitions' => $exhibitions, 'artworks' => $artworks, 'displayArtworks' => $displayArtworks, 'customers' => $customers]);
    }

    require_method('POST');
    $data = read_json();
    $action = (string)($data['action'] ?? '');
    $connection = db();

    if ($action === 'createLocation') {
        $name = trim((string)($data['name'] ?? ''));
        $building = trim((string)($data['building'] ?? ''));
        $room = trim((string)($data['room'] ?? ''));
        $address = trim((string)($data['address'] ?? ''));
        if ($name === '' || $building === '' || $room === '' || $address === '') respond(['error' => 'Complete all location fields.'], 422);
        $statement = $connection->prepare('INSERT INTO Location (location_name, building_name, room_number, street_address) VALUES (?, ?, ?, ?)');
        $statement->bind_param('ssss', $name, $building, $room, $address);
        $statement->execute();
        respond(['ok' => true, 'id' => $connection->insert_id], 201);
    }

    if ($action === 'createExhibition') {
        $locationId = filter_var($data['locationId'] ?? null, FILTER_VALIDATE_INT);
        $title = trim((string)($data['title'] ?? ''));
        $description = trim((string)($data['description'] ?? ''));
        $start = (string)($data['startDate'] ?? '');
        $end = (string)($data['endDate'] ?? '');
        $status = (string)($data['status'] ?? 'Planned');
        if (!$locationId || $title === '' || $description === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $start) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $end) || $end < $start || !in_array($status, ['Planned', 'Open', 'Closed'], true)) {
            respond(['error' => 'Enter a title, description, valid date range, location, and exhibition status.'], 422);
        }
        $statement = $connection->prepare('INSERT INTO Exhibition (location_id, exhibition_title, description, start_date, end_date, exhibition_status) VALUES (?, ?, ?, ?, ?, ?)');
        $statement->bind_param('isssss', $locationId, $title, $description, $start, $end, $status);
        $statement->execute();
        respond(['ok' => true, 'id' => $connection->insert_id], 201);
    }

    if ($action === 'recordSale') {
        $artworkId = filter_var($data['artworkId'] ?? null, FILTER_VALIDATE_INT);
        $customerId = filter_var($data['customerId'] ?? null, FILTER_VALIDATE_INT);
        if (!$artworkId || !$customerId) respond(['error' => 'Choose an artwork and customer.'], 422);
        $connection->begin_transaction();
        try {
            $lock = $connection->prepare("SELECT asking_price, availability_status FROM Artwork WHERE artwork_id = ? FOR UPDATE");
            $lock->bind_param('i', $artworkId);
            $lock->execute();
            $artwork = $lock->get_result()->fetch_assoc();
            if (!$artwork || $artwork['availability_status'] !== 'Available' || $artwork['asking_price'] === null) {
                $connection->rollback();
                respond(['error' => 'That artwork is no longer available at a sale price. Refresh the page and choose another item.'], 409);
            }
            $statement = $connection->prepare("INSERT INTO Sale (artwork_id, customer_id, recorded_by_account_id, sale_date, sale_amount, sale_status) VALUES (?, ?, ?, NOW(), ?, 'Completed')");
            $statement->bind_param('iiid', $artworkId, $customerId, $admin['account_id'], $artwork['asking_price']);
            $statement->execute();
            $saleId = $connection->insert_id;
            $connection->commit();
            respond(['ok' => true, 'saleId' => $saleId]);
        } catch (Throwable $error) {
            $connection->rollback();
            throw $error;
        }
    }

    if ($action === 'assignArtwork') {
        $exhibitionId = filter_var($data['exhibitionId'] ?? null, FILTER_VALIDATE_INT);
        $artworkId = filter_var($data['artworkId'] ?? null, FILTER_VALIDATE_INT);
        $position = filter_var($data['position'] ?? null, FILTER_VALIDATE_INT);
        $label = trim((string)($data['label'] ?? ''));
        if (!$exhibitionId || !$artworkId || !$position || $position < 1 || $label === '') respond(['error' => 'Choose an exhibition and artwork, enter a label, and use a position number above zero.'], 422);
        $statement = $connection->prepare('INSERT INTO ExhibitionArtwork (exhibition_id, artwork_id, display_label, display_position) VALUES (?, ?, ?, ?)');
        $statement->bind_param('iisi', $exhibitionId, $artworkId, $label, $position);
        $statement->execute();
        respond(['ok' => true, 'id' => $connection->insert_id], 201);
    }

    respond(['error' => 'Unknown gallery action.'], 400);
} catch (Throwable $error) {
    handle_api_error($error);
}
