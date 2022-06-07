USE playdata;

SHOW tables;

-- 1. 예지 - 플레이어생성
INSERT INTO player (id, job, sex, rid, create_date, last_date) 
VALUES ('신규플레이어01', '마법사', 'F', '신규플레이어01', '2022-06-07', '2022-06-07');

-- 2. 홍찬 - 신규 플레이어 혜택
-- 신규 플레이어는 전투력 버프를 획득합니다.
DROP TRIGGER IF EXISTS new_player_event;

CREATE TRIGGER new_player_event
AFTER INSERT
ON player
FOR EACH ROW
BEGIN
	UPDATE player
	SET str = str * 1.2;
END;

-- 3. 예지 - 유료 장비 구입
-- 신규 플레이어 특전 유료 장비를 단돈 5천원에 구매할 수 있습니다.
-- 유료 장비는 전투력을 대폭 상승시킵니다.
DROP PROCEDURE IF EXISTS auto_charge;

CREATE PROCEDURE auto_charge(player_id VARCHAR(30) BINARY)
BEGIN
	UPDATE player
	SET cash = cash + 5000, str = (str + 5000) / (lev * 5)
	WHERE id = player_id;
	COMMIT;
	SELECT id, str AS '전투력', cash
	FROM player
	WHERE id = player_id;
END;

CALL auto_charge('신규플레이어01');

-- 4. 재민 - 레벨업
-- 레벨이 1 오르며, 전투력이 100 증가합니다.
DROP PROCEDURE IF EXISTS level_up;

CREATE PROCEDURE level_up(player_id VARCHAR(30) BINARY)
BEGIN
	UPDATE player
	SET lev = lev + 1, str = str + 100
	WHERE id = player_id;
	COMMIT;
	SELECT id, lev AS '레벨', str AS '전투력'
	FROM player
	WHERE id = player_id;
END;

CALL level_up('신규플레이어01');

-- 5. 재민 - 길드 생성
-- 길드명을 입력해 길드를 생성할 수 있습니다.
DROP PROCEDURE IF EXISTS create_guild;

CREATE PROCEDURE create_guild(guild_name VARCHAR(30) BINARY)
BEGIN
	INSERT INTO guild (name, create_date)
	VALUES (guild_name, CURDATE());
	SELECT *
	FROM guild
	WHERE name = guild_name;
END;

CALL create_guild('신규길드01');


-- 6. 재민 - 길드 가입
-- 플레이어 id와 가입하고자 하는 길드명으로 길드를 가입합니다.
DROP PROCEDURE IF EXISTS signing_up_guild;

CREATE PROCEDURE signing_up_guild (player_id VARCHAR(30) BINARY, guild_name VARCHAR(30) BINARY)
BEGIN
	UPDATE player
	SET gno = (
		SELECT gno
		FROM guild
		WHERE guild.name = guild_name
	)
	WHERE id = player_id AND gno IS NULL;
	COMMIT;
	SELECT id, gno
	FROM player
	WHERE id = player_id;
END;

CALL signing_up_guild('신규플레이어01', '신규길드01');

-- 7. 재민 - 길드 탈퇴
-- 플레이어가 가입 되어 있는 길드에서 탈퇴합니다.
DROP PROCEDURE IF EXISTS leaving_guild;

CREATE PROCEDURE leaving_guild (player_id VARCHAR(30) BINARY)
BEGIN
	UPDATE player
	SET gno = NULL
	WHERE id = player_id AND gno IS NOT NULL;
	COMMIT;
	SELECT id, gno
	FROM player
	WHERE id = player_id;
END;

CALL leaving_guild('신규플레이어01');

-- 8. 재민 - 길드원 찾기
-- 직업과 최소 레벨을 조건으로 모집할 길드원을 검색할 수 있습니다.
DROP PROCEDURE IF EXISTS find_new_member;

CREATE PROCEDURE find_new_member(player_job VARCHAR(10), player_lev SMALLINT)
BEGIN
	SELECT id, job, lev
	FROM player
	WHERE job = player_job 
		AND lev >= player_lev
		AND gno IS NULL;
END;

CALL find_new_member('전사', 100);

-- 9. 재민 - 길드 평균 전투력
-- 길드의 평균 전투력을 측정합니다.
SELECT name AS '길드명', AVG(str) AS '길드원 평균 전투력'
FROM player P, guild G
WHERE P.gno = G.gno
GROUP BY P.gno
ORDER BY AVG(str) DESC;

-- 10. 예지 - 던전 매칭을 위한 파티원 찾기
-- 레벨 100 이하 던전을 돌기 위해 파티원을 찾습니다.
SELECT id, lev AS '레벨', str AS '전투력'
FROM player
WHERE lev <= 100
ORDER BY job ASC;

-- 11 . 예지 - 전투력 2배 상승 유료 아이템 구매
-- 던전 클리어를 위한 유료 아이템을 판매합니다.
DROP PROCEDURE IF EXISTS purchase_item;

CREATE PROCEDURE purchase_item(player_id VARCHAR(30) BINARY, increase INT, charge INT)
BEGIN
	UPDATE player
	SET str = str * increase, cash = cash + charge
	WHERE id = player_id;
	COMMIT;
	SELECT id, str AS '전투력', cash
	FROM player
	WHERE id = player_id;
END;

CALL purchase_item('신규플레이어01', 2, 3000);

-- 12. 홍찬 - PVP 매칭
-- PVP 매칭을 위해 플레이어를 검색합니다.
-- 매칭은 +- 1000 전투력 사이의 플레이어들 끼리만 가능하며, 매칭을 원하지 않는 직업을 지정할 수 있습니다.
DROP PROCEDURE IF EXISTS pvp_matching;

CREATE PROCEDURE pvp_matching(player_id VARCHAR(30) BINARY, player_job VARCHAR(10))
BEGIN
	IF player_job = '없음' THEN
		SELECT id, job, str
		FROM player
		WHERE str 
			BETWEEN (
				SELECT str
				FROM player
				WHERE id = player_id
			) - 1000
			AND (
				SELECT str
				FROM player
				WHERE id = player_id
			) + 1000
			AND rid NOT IN (
				SELECT rid
				FROM player
				WHERE id = player_id
			)
		ORDER BY str DESC;
	ELSE
		SELECT id, job, str
		FROM player
		WHERE str 
			BETWEEN (
				SELECT str
				FROM player
				WHERE id = player_id
			) - 1000
			AND (
				SELECT str
				FROM player
				WHERE id = player_id
			) + 1000
			AND rid NOT IN (
				SELECT rid
				FROM player
				WHERE id = player_id
			)
			AND job != player_job
		ORDER BY str DESC;
	END IF;
END;

CALL pvp_matching('10점만점', '없음');
CALL pvp_matching('10점만점', '전사');

-- 13. 홍찬 - 친구 찾기
-- 친구의 대표 id(rid)를 사용해 친구의 모든 플레이어 id를 검색합니다.
DROP PROCEDURE IF EXISTS find_friend;

CREATE PROCEDURE find_friend(player_id VARCHAR(30) BINARY)
BEGIN
	SELECT id
	FROM player
	WHERE rid = player_id
	ORDER BY id ASC;
END;

CALL find_friend('빅토르');

-- 14. 재민 - 선물 상자 이벤트
-- 게임사는 결제 금액에 따라 차등으로 선물 상자를 지급하는 이벤트를 진행하려고 합니다.
-- 선물상자는 대표 플레이어 ID의 총 결제 금액에 따라 지급됩니다.
-- 이벤트 담당자는 이벤트 진행을 위해 유저 별로 지급되는 선물 상자를 검색합니다.
SELECT rid,
	CASE
		WHEN SUM(cash) BETWEEN 0 AND 99000 THEN '평범한 선물상자'
		WHEN SUM(cash) BETWEEN 100000 AND 990000 THEN '동 선물상자'
		WHEN SUM(cash) BETWEEN 1000000 AND 4990000 THEN '은 선물상자'
		WHEN SUM(cash) BETWEEN 5000000 AND 9990000 THEN '금 선물상자'
		WHEN SUM(cash) BETWEEN 10000000 AND 19990000 THEN '플래티넘 선물상자'
		WHEN SUM(cash) >= 20000000 THEN '다이아 선물상자'
	END AS '이벤트 선물상자'
FROM player
GROUP BY rid
ORDER BY SUM(cash) DESC;

-- 15. 홍찬 - 복귀 이벤트
-- 복귀 이벤트를 진행합니다!
-- 3달 이상 6달 미만 미접속 시 복귀 상자를 받을 수 있습니다!
-- 6달 이상 미접속 시 플래티넘 복귀 상자를 받을 수 있습니다!
SELECT id, last_date AS '최근 접속일', TIMESTAMPDIFF(MONTH, last_date, CURDATE()) AS '최근 접속일로부터 경과 시간',
CASE
	WHEN TIMESTAMPDIFF(MONTH, last_date, CURDATE()) BETWEEN 3 AND 5 THEN '복귀 상자'
	WHEN TIMESTAMPDIFF(MONTH, last_date, CURDATE()) >= 6 THEN '플래티넘 복귀 상자'
	ELSE 'X'
END AS '복귀 이벤트 대상'
FROM player
ORDER BY TIMESTAMPDIFF(MONTH, last_date, CURDATE()) DESC;

-- 16. 홍찬 - 직업, 성별 비율
SELECT job AS 직업, count(*) AS '플레이어 수',
    count(CASE WHEN sex='M' THEN 1 end) AS '남자 플레이어',
    count(CASE WHEN sex='F' THEN 1 END) AS '여자 플레이어',
    round((count(*)/(SELECT count(*) FROM player))*100, 1) AS '직업 비율 %'
FROM player 
GROUP BY job 
ORDER BY count(*) DESC;
