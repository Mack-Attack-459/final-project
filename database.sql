-- COSC 459 Final Project — Milestone 2, Part 2
-- Campus Artwork Exhibit
-- Students: Okikioluwa Popoola and Jesse Obasi

-- MySQL script. Re-running this file rebuilds the database from the beginning.

DROP DATABASE IF EXISTS `campus_artwork_exhibit`;
CREATE DATABASE `campus_artwork_exhibit`;
USE `campus_artwork_exhibit`;

-- Parent table: one account stores authentication and role information.
CREATE TABLE `Account` (
    `account_id` INT AUTO_INCREMENT PRIMARY KEY,
    `first_name` VARCHAR(60) NOT NULL,
    `last_name` VARCHAR(60) NOT NULL,
    `email` VARCHAR(254) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` VARCHAR(20) NOT NULL,
    `account_status` VARCHAR(10) NOT NULL DEFAULT 'Active',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `chk_account_role`
        CHECK (`role` IN ('Artist', 'Customer', 'Administrator')),
    CONSTRAINT `chk_account_status`
        CHECK (`account_status` IN ('Active', 'Inactive'))
);

-- Artist profile; account_id is unique so one account has at most one profile.
CREATE TABLE `Artist` (
    `artist_id` INT AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT NOT NULL UNIQUE,
    `display_name` VARCHAR(120) NOT NULL,
    `biography` TEXT NOT NULL,
    `art_medium` VARCHAR(100) NOT NULL,
    `profile_photo_url` VARCHAR(2048) NULL,
    CONSTRAINT `fk_artist_account`
        FOREIGN KEY (`account_id`) REFERENCES `Account` (`account_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Customer profile; phone_number is optional in the approved design.
CREATE TABLE `Customer` (
    `customer_id` INT AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT NOT NULL UNIQUE,
    `phone_number` VARCHAR(25) NULL,
    CONSTRAINT `fk_customer_account`
        FOREIGN KEY (`account_id`) REFERENCES `Account` (`account_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Keep role-specific profile rows attached to accounts with the matching role.
DELIMITER //
CREATE TRIGGER `trg_artist_before_insert`
BEFORE INSERT ON `Artist`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT `role` INTO v_role FROM `Account` WHERE `account_id` = NEW.`account_id`;
    IF v_role IS NULL OR v_role <> 'Artist' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Artist profile must reference an Artist account';
    END IF;
END//

CREATE TRIGGER `trg_artist_before_update`
BEFORE UPDATE ON `Artist`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT `role` INTO v_role FROM `Account` WHERE `account_id` = NEW.`account_id`;
    IF v_role IS NULL OR v_role <> 'Artist' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Artist profile must reference an Artist account';
    END IF;
END//

CREATE TRIGGER `trg_customer_before_insert`
BEFORE INSERT ON `Customer`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT `role` INTO v_role FROM `Account` WHERE `account_id` = NEW.`account_id`;
    IF v_role IS NULL OR v_role <> 'Customer' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer profile must reference a Customer account';
    END IF;
END//

CREATE TRIGGER `trg_customer_before_update`
BEFORE UPDATE ON `Customer`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT `role` INTO v_role FROM `Account` WHERE `account_id` = NEW.`account_id`;
    IF v_role IS NULL OR v_role <> 'Customer' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer profile must reference a Customer account';
    END IF;
END//
DELIMITER ;

-- Artwork belongs to one artist. A non-sale item may have no asking price.
CREATE TABLE `Artwork` (
    `artwork_id` INT AUTO_INCREMENT PRIMARY KEY,
    `artist_id` INT NOT NULL,
    `title` VARCHAR(160) NOT NULL,
    `description` TEXT NOT NULL,
    `medium` VARCHAR(100) NOT NULL,
    `creation_year` YEAR NOT NULL,
    `image_url` VARCHAR(2048) NOT NULL,
    `asking_price` DECIMAL(10,2) NULL,
    `availability_status` VARCHAR(20) NOT NULL DEFAULT 'Available',
    CONSTRAINT `fk_artwork_artist`
        FOREIGN KEY (`artist_id`) REFERENCES `Artist` (`artist_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `chk_artwork_price`
        CHECK (`asking_price` IS NULL OR `asking_price` >= 0),
    CONSTRAINT `chk_artwork_availability`
        CHECK (`availability_status` IN ('Available', 'Not for Sale', 'Sold'))
);

-- Parent table for exhibitions.
CREATE TABLE `Location` (
    `location_id` INT AUTO_INCREMENT PRIMARY KEY,
    `location_name` VARCHAR(120) NOT NULL,
    `building_name` VARCHAR(120) NOT NULL,
    `room_number` VARCHAR(30) NOT NULL,
    `street_address` VARCHAR(255) NOT NULL
);

CREATE TABLE `Exhibition` (
    `exhibition_id` INT AUTO_INCREMENT PRIMARY KEY,
    `location_id` INT NOT NULL,
    `exhibition_title` VARCHAR(160) NOT NULL,
    `description` TEXT NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `exhibition_status` VARCHAR(10) NOT NULL DEFAULT 'Planned',
    CONSTRAINT `fk_exhibition_location`
        FOREIGN KEY (`location_id`) REFERENCES `Location` (`location_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `chk_exhibition_dates` CHECK (`end_date` >= `start_date`),
    CONSTRAINT `chk_exhibition_status`
        CHECK (`exhibition_status` IN ('Planned', 'Open', 'Closed'))
);

-- Bridge table records which artworks are displayed at each exhibition.
CREATE TABLE `ExhibitionArtwork` (
    `exhibition_artwork_id` INT AUTO_INCREMENT PRIMARY KEY,
    `exhibition_id` INT NOT NULL,
    `artwork_id` INT NOT NULL,
    `display_label` VARCHAR(255) NOT NULL,
    `display_position` INT NOT NULL,
    CONSTRAINT `fk_ea_exhibition`
        FOREIGN KEY (`exhibition_id`) REFERENCES `Exhibition` (`exhibition_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `fk_ea_artwork`
        FOREIGN KEY (`artwork_id`) REFERENCES `Artwork` (`artwork_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `uq_ea_exhibition_artwork` UNIQUE (`exhibition_id`, `artwork_id`),
    CONSTRAINT `uq_ea_exhibition_position` UNIQUE (`exhibition_id`, `display_position`),
    CONSTRAINT `chk_ea_display_position` CHECK (`display_position` > 0)
);

CREATE TABLE `Sale` (
    `sale_id` INT AUTO_INCREMENT PRIMARY KEY,
    `artwork_id` INT NOT NULL,
    `customer_id` INT NOT NULL,
    `recorded_by_account_id` INT NOT NULL,
    `sale_date` DATETIME NOT NULL,
    `sale_amount` DECIMAL(10,2) NOT NULL,
    `sale_status` VARCHAR(10) NOT NULL DEFAULT 'Pending',
    CONSTRAINT `fk_sale_artwork`
        FOREIGN KEY (`artwork_id`) REFERENCES `Artwork` (`artwork_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `fk_sale_customer`
        FOREIGN KEY (`customer_id`) REFERENCES `Customer` (`customer_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `fk_sale_recorded_by`
        FOREIGN KEY (`recorded_by_account_id`) REFERENCES `Account` (`account_id`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `chk_sale_amount` CHECK (`sale_amount` >= 0),
    CONSTRAINT `chk_sale_status`
        CHECK (`sale_status` IN ('Pending', 'Completed', 'Cancelled'))
);

-- Enforce the proposal's sale rules: only an administrator records a sale,
-- and a completed sale can only be made for available artwork once.
DELIMITER //
CREATE TRIGGER `trg_sale_before_insert`
BEFORE INSERT ON `Sale`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_availability VARCHAR(20);
    DECLARE v_completed_count INT DEFAULT 0;

    SELECT `role` INTO v_role
      FROM `Account` WHERE `account_id` = NEW.`recorded_by_account_id`;
    IF v_role IS NULL OR v_role <> 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an Administrator can record a sale';
    END IF;

    IF NEW.`sale_status` = 'Completed' THEN
        SELECT `availability_status` INTO v_availability
          FROM `Artwork` WHERE `artwork_id` = NEW.`artwork_id`;
        SELECT COUNT(*) INTO v_completed_count
          FROM `Sale`
          WHERE `artwork_id` = NEW.`artwork_id` AND `sale_status` = 'Completed';
        IF v_availability <> 'Available' OR v_completed_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed sale requires available artwork with no completed sale';
        END IF;
    END IF;
END//

CREATE TRIGGER `trg_sale_after_insert`
AFTER INSERT ON `Sale`
FOR EACH ROW
BEGIN
    IF NEW.`sale_status` = 'Completed' THEN
        UPDATE `Artwork`
           SET `availability_status` = 'Sold'
         WHERE `artwork_id` = NEW.`artwork_id`;
    END IF;
END//

CREATE TRIGGER `trg_sale_before_update`
BEFORE UPDATE ON `Sale`
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_availability VARCHAR(20);
    DECLARE v_completed_count INT DEFAULT 0;

    SELECT `role` INTO v_role
      FROM `Account` WHERE `account_id` = NEW.`recorded_by_account_id`;
    IF v_role IS NULL OR v_role <> 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an Administrator can record a sale';
    END IF;

    IF OLD.`sale_status` = 'Completed'
       AND (NEW.`sale_status` <> 'Completed' OR NEW.`artwork_id` <> OLD.`artwork_id`) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed sales are retained and cannot be reassigned';
    END IF;

    IF NEW.`sale_status` = 'Completed' AND OLD.`sale_status` <> 'Completed' THEN
        SELECT `availability_status` INTO v_availability
          FROM `Artwork` WHERE `artwork_id` = NEW.`artwork_id`;
        SELECT COUNT(*) INTO v_completed_count
          FROM `Sale`
          WHERE `artwork_id` = NEW.`artwork_id`
            AND `sale_status` = 'Completed'
            AND `sale_id` <> OLD.`sale_id`;
        IF v_availability <> 'Available' OR v_completed_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed sale requires available artwork with no completed sale';
        END IF;
    END IF;
END//

CREATE TRIGGER `trg_sale_after_update`
AFTER UPDATE ON `Sale`
FOR EACH ROW
BEGIN
    IF NEW.`sale_status` = 'Completed' AND OLD.`sale_status` <> 'Completed' THEN
        UPDATE `Artwork`
           SET `availability_status` = 'Sold'
         WHERE `artwork_id` = NEW.`artwork_id`;
    END IF;
END//
DELIMITER ;

-- Realistic sample data: 10 Artist, Customer, Location, and Exhibition records;
-- 11 Sale records so the table remains above its minimum after a DELETE;
-- 30 Accounts; 15 Artwork records; and 12 bridge-table records.
INSERT INTO `Account`
    (`account_id`, `first_name`, `last_name`, `email`, `password_hash`, `role`, `account_status`, `created_at`)
VALUES
    (1,'Amina','Cole','amina.cole@example.edu',SHA2('demo-password-01!', 256),'Artist','Active','2026-01-10 09:00:00'),
    (2,'Jordan','Reed','jordan.reed@example.edu',SHA2('demo-password-02!', 256),'Artist','Active','2026-01-11 09:00:00'),
    (3,'Nia','Brooks','nia.brooks@example.edu',SHA2('demo-password-03!', 256),'Artist','Active','2026-01-12 09:00:00'),
    (4,'Malik','Price','malik.price@example.edu',SHA2('demo-password-04!', 256),'Artist','Active','2026-01-13 09:00:00'),
    (5,'Zara','Fields','zara.fields@example.edu',SHA2('demo-password-05!', 256),'Artist','Active','2026-01-14 09:00:00'),
    (6,'Ethan','Miles','ethan.miles@example.edu',SHA2('demo-password-06!', 256),'Artist','Active','2026-01-15 09:00:00'),
    (7,'Imani','Gray','imani.gray@example.edu',SHA2('demo-password-07!', 256),'Artist','Active','2026-01-16 09:00:00'),
    (8,'Noah','Bennett','noah.bennett@example.edu',SHA2('demo-password-08!', 256),'Artist','Active','2026-01-17 09:00:00'),
    (9,'Amara','Young','amara.young@example.edu',SHA2('demo-password-09!', 256),'Artist','Active','2026-01-18 09:00:00'),
    (10,'Caleb','Ward','caleb.ward@example.edu',SHA2('demo-password-10!', 256),'Artist','Active','2026-01-19 09:00:00'),
    (11,'Olivia','King','olivia.king@example.edu',SHA2('demo-password-01!', 256),'Customer','Active','2026-01-20 09:00:00'),
    (12,'Liam','Scott','liam.scott@example.edu',SHA2('demo-password-02!', 256),'Customer','Active','2026-01-21 09:00:00'),
    (13,'Maya','Adams','maya.adams@example.edu',SHA2('demo-password-03!', 256),'Customer','Active','2026-01-22 09:00:00'),
    (14,'Evan','Hill','evan.hill@example.edu',SHA2('demo-password-04!', 256),'Customer','Active','2026-01-23 09:00:00'),
    (15,'Aaliyah','Baker','aaliyah.baker@example.edu',SHA2('demo-password-05!', 256),'Customer','Active','2026-01-24 09:00:00'),
    (16,'James','Rivera','james.rivera@example.edu',SHA2('demo-password-06!', 256),'Customer','Active','2026-01-25 09:00:00'),
    (17,'Sofia','Cox','sofia.cox@example.edu',SHA2('demo-password-07!', 256),'Customer','Active','2026-01-26 09:00:00'),
    (18,'Mason','Howard','mason.howard@example.edu',SHA2('demo-password-08!', 256),'Customer','Active','2026-01-27 09:00:00'),
    (19,'Chloe','Bell','chloe.bell@example.edu',SHA2('demo-password-09!', 256),'Customer','Active','2026-01-28 09:00:00'),
    (20,'Lucas','Cook','lucas.cook@example.edu',SHA2('demo-password-10!', 256),'Customer','Active','2026-01-29 09:00:00'),
    (21,'Morgan','James','morgan.james@example.edu',SHA2('demo-password-01!', 256),'Administrator','Active','2026-01-02 09:00:00'),
    (22,'Taylor','Lewis','taylor.lewis@example.edu',SHA2('demo-password-02!', 256),'Administrator','Active','2026-01-03 09:00:00'),
    (23,'Riley','Walker','riley.walker@example.edu',SHA2('demo-password-03!', 256),'Administrator','Active','2026-01-04 09:00:00'),
    (24,'Casey','Hall','casey.hall@example.edu',SHA2('demo-password-04!', 256),'Administrator','Active','2026-01-05 09:00:00'),
    (25,'Drew','Allen','drew.allen@example.edu',SHA2('demo-password-05!', 256),'Administrator','Active','2026-01-06 09:00:00'),
    (26,'Avery','Harris','avery.harris@example.edu',SHA2('demo-password-06!', 256),'Administrator','Active','2026-01-07 09:00:00'),
    (27,'Quinn','Nelson','quinn.nelson@example.edu',SHA2('demo-password-07!', 256),'Administrator','Active','2026-01-08 09:00:00'),
    (28,'Skyler','Carter','skyler.carter@example.edu',SHA2('demo-password-08!', 256),'Administrator','Active','2026-01-09 09:00:00'),
    (29,'Parker','Mitchell','parker.mitchell@example.edu',SHA2('demo-password-09!', 256),'Administrator','Active','2026-01-30 09:00:00'),
    (30,'Rowan','Turner','rowan.turner@example.edu',SHA2('demo-password-10!', 256),'Administrator','Active','2026-01-31 09:00:00');

INSERT INTO `Artist` (`artist_id`, `account_id`, `display_name`, `biography`, `art_medium`, `profile_photo_url`) VALUES
    (1,1,'Amina Cole','Creates layered portraits inspired by family stories.','Painting','https://example.edu/artists/amina.jpg'),
    (2,2,'Jordan Reed','Explores city life through bold color and shape.','Digital art','https://example.edu/artists/jordan.jpg'),
    (3,3,'Nia Brooks','Makes sculpture from reclaimed campus materials.','Sculpture',NULL),
    (4,4,'Malik Price','Studies rhythm and movement in abstract work.','Mixed media','https://example.edu/artists/malik.jpg'),
    (5,5,'Zara Fields','Creates textile pieces about memory and place.','Textile','https://example.edu/artists/zara.jpg'),
    (6,6,'Ethan Miles','Photographs overlooked details around Baltimore.','Photography',NULL),
    (7,7,'Imani Gray','Illustrates stories about community and belonging.','Illustration','https://example.edu/artists/imani.jpg'),
    (8,8,'Noah Bennett','Builds small forms from wood and found objects.','Woodwork','https://example.edu/artists/noah.jpg'),
    (9,9,'Amara Young','Uses watercolor to document campus gardens.','Watercolor',NULL),
    (10,10,'Caleb Ward','Creates geometric prints with repeated patterns.','Printmaking','https://example.edu/artists/caleb.jpg');

INSERT INTO `Customer` (`customer_id`, `account_id`, `phone_number`) VALUES
    (1,11,'410-555-0101'),(2,12,'410-555-0102'),(3,13,NULL),(4,14,'410-555-0104'),
    (5,15,'410-555-0105'),(6,16,NULL),(7,17,'410-555-0107'),(8,18,'410-555-0108'),
    (9,19,NULL),(10,20,'410-555-0110');

INSERT INTO `Artwork`
    (`artwork_id`, `artist_id`, `title`, `description`, `medium`, `creation_year`, `image_url`, `asking_price`, `availability_status`)
VALUES
    (1,1,'Blue Hour Portrait','A layered portrait about finding calm after a busy day.','Acrylic on canvas',2025,'https://example.edu/artwork/1.jpg',320.00,'Available'),
    (2,2,'North Avenue Lines','A digital study of movement along a city street.','Digital print',2025,'https://example.edu/artwork/2.jpg',275.00,'Available'),
    (3,3,'Second Life Form','A small sculpture made from reused campus materials.','Reclaimed metal',2024,'https://example.edu/artwork/3.jpg',450.00,'Available'),
    (4,4,'Pulse in Red','An abstract mixed-media piece about rhythm.','Acrylic and paper',2025,'https://example.edu/artwork/4.jpg',390.00,'Available'),
    (5,5,'Family Threads','A textile panel built from repeated stitched patterns.','Cotton textile',2024,'https://example.edu/artwork/5.jpg',180.00,'Available'),
    (6,6,'Campus After Rain','A photograph of reflections on a campus walkway.','Photography',2025,'https://example.edu/artwork/6.jpg',125.00,'Available'),
    (7,7,'The Welcome Table','An illustration of a community gathering.','Ink and digital color',2025,'https://example.edu/artwork/7.jpg',210.00,'Available'),
    (8,8,'Small Grove','A hand-carved wood study of a tree.','Maple wood',2024,'https://example.edu/artwork/8.jpg',260.00,'Available'),
    (9,9,'Garden Notes','A watercolor study of flowers near the library.','Watercolor on paper',2025,'https://example.edu/artwork/9.jpg',95.00,'Available'),
    (10,10,'Repeated Steps','A geometric print about everyday routines.','Screen print',2025,'https://example.edu/artwork/10.jpg',150.00,'Available'),
    (11,1,'Window Light','A small painting of afternoon light in a studio.','Oil on canvas',2024,'https://example.edu/artwork/11.jpg',500.00,'Available'),
    (12,2,'Market Morning','A colorful digital illustration of a neighborhood market.','Digital print',2026,'https://example.edu/artwork/12.jpg',NULL,'Not for Sale'),
    (13,5,'Blue Stitch Study','A study of blue thread and woven texture.','Textile',2026,'https://example.edu/artwork/13.jpg',220.00,'Available'),
    (14,8,'Found Shapes','A wood assemblage built from offcuts.','Wood and found objects',2025,'https://example.edu/artwork/14.jpg',340.00,'Available'),
    (15,10,'Campus Grid','A limited print inspired by campus paths.','Screen print',2026,'https://example.edu/artwork/15.jpg',175.00,'Available');

INSERT INTO `Location` (`location_id`, `location_name`, `building_name`, `room_number`, `street_address`) VALUES
    (1,'Student Gallery','Murphy Fine Arts Center','Gallery 101','2201 Argonne Drive, Baltimore, MD'),
    (2,'Library Atrium','Earl S. Richardson Library','Atrium','1100 W. Cold Spring Lane, Baltimore, MD'),
    (3,'North Campus Gallery','Jenkins Hall','Room 112','2201 Argonne Drive, Baltimore, MD'),
    (4,'Arts Studio Hall','Fine Arts Building','Room 204','2201 Argonne Drive, Baltimore, MD'),
    (5,'Alumni Gallery','Tyler Hall','Room 18','1700 E. Cold Spring Lane, Baltimore, MD'),
    (6,'Student Center Showcase','University Student Center','Second Floor','1700 E. Cold Spring Lane, Baltimore, MD'),
    (7,'Garden Walk Display','Campus Garden Pavilion','Outdoor Wall','1700 E. Cold Spring Lane, Baltimore, MD'),
    (8,'Digital Arts Room','Murphy Fine Arts Center','Room 315','2201 Argonne Drive, Baltimore, MD'),
    (9,'Community Room Gallery','Jenkins Hall','Room 206','2201 Argonne Drive, Baltimore, MD'),
    (10,'East Hall Exhibit Space','East Campus Hall','Room 10','1700 E. Cold Spring Lane, Baltimore, MD');

INSERT INTO `Exhibition` (`exhibition_id`, `location_id`, `exhibition_title`, `description`, `start_date`, `end_date`, `exhibition_status`) VALUES
    (1,1,'New Voices','Student work introducing emerging campus artists.','2026-09-01','2026-09-30','Closed'),
    (2,2,'Baltimore in Color','Artwork reflecting the city and its neighborhoods.','2026-10-01','2026-11-30','Open'),
    (3,3,'Material Stories','Sculpture and mixed media made with varied materials.','2026-11-10','2026-12-15','Planned'),
    (4,4,'Threads of Home','Textile art about family, memory, and place.','2026-09-15','2026-10-15','Closed'),
    (5,5,'Campus Light','Photography and painting inspired by campus spaces.','2026-10-20','2026-12-01','Open'),
    (6,6,'Small Works','Affordable small-scale art by student creators.','2026-11-15','2026-12-20','Planned'),
    (7,7,'Garden Observations','Artworks inspired by the campus garden.','2026-08-01','2026-08-31','Closed'),
    (8,8,'Digital Directions','Digital illustration, print, and design work.','2026-11-01','2026-12-10','Open'),
    (9,9,'Patterns and Repetition','Printmaking and repeated visual forms.','2026-12-01','2027-01-15','Planned'),
    (10,10,'Community Portraits','Portraits and stories from the university community.','2026-10-05','2026-11-05','Closed');

INSERT INTO `ExhibitionArtwork` (`exhibition_artwork_id`, `exhibition_id`, `artwork_id`, `display_label`, `display_position`) VALUES
    (1,1,1,'Blue Hour Portrait — Amina Cole',1),
    (2,1,5,'Family Threads — Zara Fields',2),
    (3,2,2,'North Avenue Lines — Jordan Reed',1),
    (4,2,6,'Campus After Rain — Ethan Miles',2),
    (5,3,3,'Second Life Form — Nia Brooks',1),
    (6,3,8,'Small Grove — Noah Bennett',2),
    (7,4,5,'Threads of Home — Zara Fields',1),
    (8,5,6,'Campus After Rain — Ethan Miles',1),
    (9,6,9,'Garden Notes — Amara Young',1),
    (10,8,7,'The Welcome Table — Imani Gray',1),
    (11,9,10,'Repeated Steps — Caleb Ward',1),
    (12,10,4,'Pulse in Red — Malik Price',1);

INSERT INTO `Sale` (`sale_id`, `artwork_id`, `customer_id`, `recorded_by_account_id`, `sale_date`, `sale_amount`, `sale_status`) VALUES
    (1,1,1,21,'2026-09-05 13:10:00',310.00,'Completed'),
    (2,2,2,22,'2026-09-08 14:20:00',275.00,'Completed'),
    (3,3,3,23,'2026-09-12 11:30:00',425.00,'Completed'),
    (4,4,4,24,'2026-09-16 15:40:00',390.00,'Completed'),
    (5,5,5,25,'2026-10-02 10:00:00',180.00,'Pending'),
    (6,6,6,26,'2026-10-06 12:15:00',125.00,'Cancelled'),
    (7,7,7,27,'2026-10-09 13:30:00',210.00,'Pending'),
    (8,8,8,28,'2026-10-12 16:00:00',260.00,'Cancelled'),
    (9,9,9,29,'2026-10-18 09:45:00',95.00,'Pending'),
    (10,10,10,30,'2026-10-21 14:25:00',150.00,'Cancelled'),
    (11,11,10,29,'2026-10-23 11:00:00',500.00,'Cancelled');

-- 15 required SQL statements. Each comment says what the statement demonstrates.

-- 1. Retrieval: show every column from the Artwork table.
SELECT *
FROM `Artwork`;

-- 2. Retrieval: connect exhibition placements to artwork and its artist.
SELECT e.`exhibition_title`, a.`title` AS `artwork_title`, ar.`display_name`, ea.`display_position`
FROM `ExhibitionArtwork` ea
JOIN `Exhibition` e ON e.`exhibition_id` = ea.`exhibition_id`
JOIN `Artwork` a ON a.`artwork_id` = ea.`artwork_id`
JOIN `Artist` ar ON ar.`artist_id` = a.`artist_id`;

-- 3. Filter: find artwork that is available to purchase.
SELECT `artwork_id`, `title`, `asking_price`
FROM `Artwork`
WHERE `availability_status` = 'Available';

-- 4. Filter: find art priced from $100 through $300.
SELECT `artwork_id`, `title`, `asking_price`
FROM `Artwork`
WHERE `asking_price` BETWEEN 100.00 AND 300.00;

-- 5. Filter: find exhibition titles that contain the word Color.
SELECT `exhibition_id`, `exhibition_title`, `start_date`, `end_date`
FROM `Exhibition`
WHERE `exhibition_title` LIKE '%Color%';

-- 6. Sort: list artwork from least to most expensive, with unpriced work last.
SELECT `title`, `asking_price`
FROM `Artwork`
ORDER BY `asking_price` IS NULL, `asking_price` ASC;

-- 7. Sort: list exhibitions from the most recent start date to the earliest.
SELECT `exhibition_title`, `start_date`, `exhibition_status`
FROM `Exhibition`
ORDER BY `start_date` DESC;

-- 8. Aggregate: count the complete artwork inventory.
SELECT COUNT(*) AS `artwork_count`
FROM `Artwork`;

-- 9. Aggregate: calculate completed-sale revenue and average sale amount.
SELECT SUM(`sale_amount`) AS `completed_revenue`, AVG(`sale_amount`) AS `average_completed_sale`
FROM `Sale`
WHERE `sale_status` = 'Completed';

-- 10. Group: count sales in each status.
SELECT `sale_status`, COUNT(*) AS `number_of_sales`
FROM `Sale`
GROUP BY `sale_status`
ORDER BY `sale_status`;

-- 11. Group: count the registered artwork for each artist.
SELECT ar.`display_name`, COUNT(a.`artwork_id`) AS `artwork_count`
FROM `Artist` ar
LEFT JOIN `Artwork` a ON a.`artist_id` = ar.`artist_id`
GROUP BY ar.`artist_id`, ar.`display_name`
ORDER BY `artwork_count` DESC, ar.`display_name`;

-- 12. Update: deactivate the selected administrator account.
UPDATE `Account`
SET `account_status` = 'Inactive'
WHERE `account_id` = 30;

-- 13. Update: adjust the asking price for one available artwork.
UPDATE `Artwork`
SET `asking_price` = 185.00
WHERE `artwork_id` = 15 AND `availability_status` = 'Available';

-- 14. Delete: remove one cancelled sale record, retaining completed history.
DELETE FROM `Sale`
WHERE `sale_id` = 10 AND `sale_status` = 'Cancelled';

-- 15. Delete: remove one display assignment while keeping exhibition and artwork.
DELETE FROM `ExhibitionArtwork`
WHERE `exhibition_artwork_id` = 12;
