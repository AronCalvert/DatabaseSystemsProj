-- 1.1
CREATE VIEW actor_minutes AS
SELECT a.actor_id, a.actor_name, SUM(uh.minutes_played) AS total_minutes_played
FROM actors a
LEFT JOIN actor_episode ae ON a.actor_id = ae.actor_id
LEFT JOIN episodes e ON ae.episode_id = e.episode_id
LEFT JOIN user_history uh ON e.episode_id = uh.episode_id
GROUP BY a.actor_id, a.actor_name;

--1.2
-- View 1: Create a view with the maximum rating for all series
CREATE VIEW top_series_rating AS
SELECT
    series_id,
    MAX(rating) AS max_rating
FROM
    series
GROUP BY
    series_id;

-- View 2: Create a view with all the actors who play in at least one episode of each series
CREATE VIEW series_actors AS
SELECT
    s.series_id,
    GROUP_CONCAT(DISTINCT a.actor_name) AS cast
FROM
    series s
JOIN
    episodes e ON s.series_id = e.series_id
JOIN
    actor_episode ae ON e.episode_id = ae.episode_id
JOIN
    actors a ON ae.actor_id = a.actor_id
GROUP BY
    s.series_id;

-- Top Series Cast View: Create a view with the top series above a rating of 4.00 using series ID, Title and their cast
CREATE VIEW top_series_cast AS
SELECT
    s.series_id,
    s.series_title,
    sa.cast
FROM
    series s
JOIN
    top_series_rating tr ON s.series_id = tr.series_id
JOIN
    series_actors sa ON s.series_id = sa.series_id
WHERE
    tr.max_rating >= 4.00;


-- 1.3
DELIMITER //
CREATE TRIGGER AdjustRating
BEFORE INSERT ON user_history
FOR EACH ROW
BEGIN
    DECLARE episode_length REAL;
    DECLARE series_rating DOUBLE;

    -- a. If x is less than or equal to length of episode
    SELECT episode_length INTO episode_length
    FROM episodes
    WHERE episode_id = NEW.episode_id;

    IF NEW.minutes_played > episode_length THEN
        SET NEW.minutes_played = episode_length;
    END IF;

    -- b. Add 0.0001 * x to rating
    SELECT rating INTO series_rating
    FROM series
    WHERE series_id = (
        SELECT series_id
        FROM episodes
        WHERE episode_id = NEW.episode_id
    );

    IF series_rating < 5.00 THEN
        SET series_rating = series_rating + 0.0001 * NEW.minutes_played;

        -- Update rating of series
        UPDATE series
        SET rating = series_rating
        WHERE series_id = (
            SELECT series_id
            FROM episodes
            WHERE episode_id = NEW.episode_id
        );
    END IF;
END //
DELIMITER ;






--1.4
DELIMITER //


CREATE PROCEDURE AddEpisode(
    IN s_id INT(10),
    IN s_number TINYINT(4),
    IN e_number TINYINT(4),
    IN e_title VARCHAR(128),
    IN e_length REAL
)
BEGIN
    IF EXISTS (SELECT 1 FROM series WHERE series_id = s_id) AND
       NOT EXISTS (SELECT 1 FROM episodes WHERE series_id = s_id AND season_number = s_number AND episode_number = e_number) THEN
        INSERT INTO episodes (series_id, season_number, episode_number, episode_title, episode_length, date_of_release)
        VALUES (s_id, s_number, e_number, e_title, e_length, CURDATE());
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Invalid series_id/episode exists already';
    END IF;
END;


//


DELIMITER ;


--1.5
DELIMITER //

CREATE FUNCTION GetEpisodeList(s_id INT, s_number INT)
RETURNS VARCHAR(1024)
BEGIN
    DECLARE episode_list VARCHAR(1024);

   
    SELECT GROUP_CONCAT(episode_title ORDER BY episode_number ASC SEPARATOR ', ')
    INTO episode_list
    FROM episodes
    WHERE series_id = s_id AND season_number = s_number;

    RETURN episode_list;
END //

DELIMITER ;


