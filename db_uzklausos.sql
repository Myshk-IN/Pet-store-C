-- CONNECTING TO DB
--psql -h pgsql3.mif -d studentu

-- CREATING TABLES
CREATE TABLE Tipas(
    Tipo_id INTEGER PRIMARY KEY
            GENERATED ALWAYS AS IDENTITY(START WITH 1 INCREMENT BY 1),
    Rusis VARCHAR(20)
          CHECK(Rusis IN ('Katė', 'Žiurkė', 'Papūga', 'Jūrų kiaulytė', 'Žiurkėnas', 'Triušis', 'Šuo')),
    Veisle VARCHAR(20) 
);

CREATE TABLE Gyvunas(
    Gyvuno_id INTEGER PRIMARY KEY
              GENERATED ALWAYS AS IDENTITY(START WITH 1 INCREMENT BY 1),
    Tipo_id INTEGER NOT NULL,
    Kaina FLOAT DEFAULT 0,
    Gimimo_data DATE DEFAULT CURRENT_DATE
                     CHECK (Gimimo_data <= CURRENT_DATE),
    Vardas VARCHAR(30) DEFAULT 'Bevardis',
    Nupirktas BOOLEAN DEFAULT FALSE,
    CONSTRAINT GyvunoRaktai
     FOREIGN KEY (Tipo_id) REFERENCES Tipas (Tipo_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Pirkejas(
    Pirkejo_id INTEGER PRIMARY KEY
               GENERATED ALWAYS AS IDENTITY(START WITH 1 INCREMENT BY 1),
    El_pastas VARCHAR(255) UNIQUE
                           CHECK (CHAR_LENGTH(El_pastas) > 1 AND POSITION('@' IN El_pastas) > 0),
    Vardas VARCHAR(100) NOT NULL,
    Pavarde VARCHAR(100) NOT NULL,    
    Telefono_nr CHAR(15) NOT NULL,
    Miestas VARCHAR(50) DEFAULT 'Vilnius',
    Gatve VARCHAR(50) NOT NULL,
    Namas VARCHAR(10) NOT NULL
);

CREATE TABLE Uzsakymas(
    Uzsakymo_id INTEGER PRIMARY KEY
                GENERATED ALWAYS AS IDENTITY(START WITH 1 INCREMENT BY 1),
    Pirkejo_id INTEGER NOT NULL,
    Uzsakymo_data TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT UzsakymoRaktai
     FOREIGN KEY(Pirkejo_id) REFERENCES Pirkejas (Pirkejo_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Pirkimas(
    Uzsakymo_id INTEGER NOT NULL,
    Gyvuno_id INTEGER NOT NULL,
    CONSTRAINT PirkimoRaktai
        PRIMARY KEY (Uzsakymo_id, Gyvuno_id),
    FOREIGN KEY (Uzsakymo_id) REFERENCES Uzsakymas (Uzsakymo_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (Gyvuno_id) REFERENCES Gyvunas (Gyvuno_id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- CREATING INDECES
CREATE UNIQUE INDEX PirkejasIndex
    ON Pirkejas(Vardas, Pavarde, Telefono_nr);

CREATE INDEX UzsakymasIndex
    ON Uzsakymas(Pirkejo_id);

-- CREATING TRIGGERS
CREATE OR REPLACE FUNCTION gyvunasNupirktas()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Gyvunas
    SET Nupirktas = TRUE
    WHERE Gyvuno_id = NEW.Gyvuno_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER PakeistiNupirktas
AFTER INSERT ON Pirkimas
FOR EACH ROW
EXECUTE FUNCTION gyvunasNupirktas();

CREATE OR REPLACE FUNCTION patikrintiArNupirktas()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Gyvunas
        WHERE Gyvuno_id = NEW.Gyvuno_id AND Nupirktas = TRUE
    ) THEN
        RAISE EXCEPTION 'Negalima pirkti jau prieš tai pirktą gyvūną';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER NekeistiJeiNupirktasInsert
BEFORE INSERT ON Pirkimas
FOR EACH ROW
EXECUTE FUNCTION patikrintiArNupirktas();

-- CREATE TRIGGER NekeistiJeiNupirktasUpdate
-- BEFORE UPDATE ON Pirkimas
-- FOR EACH ROW
-- EXECUTE FUNCTION patikrintiArNupirktas();

CREATE OR REPLACE FUNCTION pakeistiNupirktasJeiPakeistasGyvunas()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.Gyvuno_id IS NOT NULL THEN
        UPDATE Gyvunas SET Nupirktas = FALSE WHERE Gyvuno_id = OLD.Gyvuno_id;
    END IF;

    IF NEW.Gyvuno_id IS NOT NULL THEN
        IF (SELECT Nupirktas FROM Gyvunas WHERE Gyvuno_id = NEW.Gyvuno_id) = FALSE THEN
            UPDATE Gyvunas SET Nupirktas = TRUE WHERE Gyvuno_id = NEW.Gyvuno_id;
        ELSE
            RAISE EXCEPTION 'Negalima pirkti jau prieš tai pirktą gyvūną';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER KeistiGyvuna
BEFORE UPDATE ON Pirkimas
FOR EACH ROW
EXECUTE FUNCTION pakeistiNupirktasJeiPakeistasGyvunas();


-- INSERTING SOME TEST DATA
INSERT INTO Tipas (Rusis, Veisle) VALUES
('Katė', 'Pilka'),
('Žiurkė', 'Juoda'),
('Papūga', 'Tropikinis'),
('Jūrų kiaulytė', 'Šilokailis'),
('Žiurkėnas', 'Didysis'),
('Triušis', 'Baltasis'),
('Šuo', 'Labradoras');

INSERT INTO Pirkejas (El_pastas, Vardas, Pavarde, Telefono_nr, Miestas, Gatve, Namas) VALUES
('pvz1@example.com', 'Vardas1', 'Pavarde1', '123456789', 'Vilnius', 'Gatve', '1'),
('pvz2@example.com', 'Vardas2', 'Pavarde2', '987654321', 'Kaunas', 'Gatve', '2'),
('pvz3@example.com', 'Vardas3', 'Pavarde3', '456789012', 'Klaipeda', 'Gatve', '3');

INSERT INTO Pirkejas (Pirkejo_id, El_pastas, Vardas, Pavarde, Telefono_nr, Miestas, Gatve, Namas) VALUES
(10, 'pvz1@example.com', 'Vardas1', 'Pavarde1', '123456789', 'Vilnius', 'Gatve', '1');

INSERT INTO Gyvunas (Tipo_id, Kaina, Gimimo_data, Vardas) VALUES
(1, 50, '2022-01-01', 'Tom'),
(3, 100, '2022-02-15', 'Charlie'),
(5, 200, '2022-03-20', 'Max');

INSERT INTO Uzsakymas (Pirkejo_id) VALUES
(1),
(2);

INSERT INTO Pirkimas (Uzsakymo_id, Gyvuno_id) VALUES
(1, 1),
(2, 3),
(1, 2);

-- CREATING VIEWS
CREATE VIEW ParduodamiGyvunai("Gyvūno kaina", "Gyvūno vardas", "Gyvūno rūšis", "Gyvūno veislė", "Gyvūno amžius") AS
SELECT G.Kaina, G.Vardas, T.Rusis, T.Veisle, AGE(CURRENT_DATE, G.Gimimo_data)
FROM Gyvunas G 
JOIN Tipas T ON G.Tipo_id = T.Tipo_id
WHERE G.Nupirktas = FALSE;

CREATE VIEW DetalizuotasUzsakymas("Bendra suma", "Vardas", "Pavarde", "Tel. nr.", "Užsakymo data", "Gyvūno kaina", "Gyvūno vardas", "Gyvūno rūšis", "Gyvūno veislė") AS
SELECT SUM(G.Kaina) OVER (PARTITION BY U.Uzsakymo_id), P.Vardas, P.Pavarde, P.Telefono_nr, U.Uzsakymo_data, G.Kaina, G.Vardas, T.Rusis, T.Veisle
FROM Uzsakymas U, Pirkimas Pi, Gyvunas G, Tipas T, Pirkejas P
WHERE U.Uzsakymo_id = Pi.Uzsakymo_id AND Pi.Gyvuno_id = G.Gyvuno_id AND G.Tipo_id = T.Tipo_id AND U.Pirkejo_id = P.Pirkejo_id;

CREATE MATERIALIZED VIEW InformacijaApiePirkejuUzsakymus("Pirkėjo id", "Nupirktų gyvūnų skaičius") AS
SELECT P.Pirkejo_id,  COUNT(Pi.Gyvuno_id)
FROM Pirkejas P, Uzsakymas U, Pirkimas Pi
WHERE P.Pirkejo_id = U.Pirkejo_id AND U.Uzsakymo_id = Pi.Uzsakymo_id AND EXTRACT(MONTH FROM U.Uzsakymo_data) = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY P.Pirkejo_id;

-- REFRESH MATERIALIZED VIEW InformacijaApiePirkejuUzsakymus;

-- DROPPING VIEWS
DROP VIEW ParduodamiGyvunai;
DROP VIEW DetalizuotasUzsakymas;
DROP MATERIALIZED VIEW InformacijaApiePirkejuUzsakymus;

-- DROPPING INDECES
DROP INDEX PirkejasIndex;
DROP INDEX UzsakymasIndex;

-- DROPPING TRIGGERS
DROP TRIGGER PakeistiNupirktas ON Pirkimas;
DROP TRIGGER NekeistiJeiNupirktasInsert ON Pirkimas;
DROP TRIGGER KeistiGyvuna ON Pirkimas;

-- DROPPING TABLES
DROP TABLE Gyvunas CASCADE;
DROP TABLE Pirkejas CASCADE;
DROP TABLE Uzsakymas CASCADE;
DROP TABLE Tipas CASCADE;
DROP TABLE Pirkimas CASCADE;

-- SELECTS
 SELECT * FROM Uzsakymas;
 SELECT * FROM Tipas;
 SELECT * FROM Pirkimas;
 SELECT * FROM Pirkejas;
 SELECT * FROM Gyvunas;

 SELECT * FROM ParduodamiGyvunai;
 SELECT * FROM DetalizuotasUzsakymas;
 SELECT * FROM InformacijaApiePirkejuUzsakymus;

-- TEST UNIQUE INDEX
INSERT INTO Pirkejas (El_pastas, Vardas, Pavarde, Telefono_nr, Miestas, Gatve, Namas) VALUES
('pas@as', 'Vardas1', 'Pavarde1', '123456789', 'aa', 'vv', '1dd');

-- TEST PakeistiNupirktas TRIGGER
INSERT INTO Gyvunas (Tipo_id, Kaina, Gimimo_data, Vardas) VALUES -- error
(1, 50, '2020-05-21', 'Benas');

INSERT INTO Pirkimas (Uzsakymo_id, Gyvuno_id) VALUES
(1, 4);

-- TEST NekeistiJeiNupirktasInsert TRIGGER
INSERT INTO Pirkimas (Uzsakymo_id, Gyvuno_id) VALUES -- error
(2, 4);

-- TEST KeistiGyvuna TRIGGER
INSERT INTO Gyvunas (Tipo_id, Kaina, Gimimo_data, Vardas) VALUES
(2, 350, '2021-05-21', 'Cinamonas');

UPDATE Pirkimas SET Gyvuno_id = 5 WHERE Gyvuno_id = 1; -- valid
UPDATE Pirkimas SET Gyvuno_id = 1 WHERE Gyvuno_id = 5; -- valid
UPDATE Pirkimas SET Gyvuno_id = 2 WHERE Gyvuno_id = 1; -- error





