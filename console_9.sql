DROP SCHEMA IF EXISTS projet CASCADE;
CREATE SCHEMA projet;

-- Vérifier si le type ENUM existe avant de le créer
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'semestre') THEN
        CREATE TYPE semestre AS ENUM ('Q1', 'Q2');
    END IF;
END $$;
--
-- -- Vérifier si la table projet.etudiants existe avant de la créer
-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'projet' AND table_name = 'etudiants') THEN
--         CREATE TABLE projet.etudiants (
--             id_etudiant SERIAL PRIMARY KEY,
--             nom VARCHAR(100) NOT NULL CHECK (nom<>''),
--             prenom VARCHAR(100) NOT NULL CHECK (prenom<>''),
--             email VARCHAR(100) NOT NULL UNIQUE CHECK (email<>''),
--             semestre semestre NOT NULL,
--             mdp VARCHAR(100) NOT NULL
--         );
--     END IF;
-- END $$;

-- Répétez ce modèle pour les autres tables et types


-- CREATE TYPE semestre AS ENUM ('Q1', 'Q2');

CREATE TABLE projet.etudiants (
    id_etudiant SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL CHECK (nom<>''),
    prenom VARCHAR(100) NOT NULL CHECK (prenom<>''),
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email<>''),
    CHECK ( email LIKE '%@student.vinci.be'),
    semestre semestre NOT NULL,
    mdp VARCHAR(100) NOT NULL
);

-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'projet' AND table_name = 'etudiants') THEN
--         CREATE TABLE projet.entreprise (
--             id_entreprise CHAR(3) PRIMARY KEY,
--             nom VARCHAR(100) NOT NULL CHECK (nom<>''),
--             adresse VARCHAR(100) NOT NULL CHECK (adresse<>''),
--             email VARCHAR(100) NOT NULL UNIQUE CHECK (email<>''),
--             mdp VARCHAR(100) NOT NULL
--         );
--     END IF;
-- END $$;

CREATE TABLE projet.entreprise (
    id_entreprise CHAR(3) PRIMARY KEY CHECK ( id_entreprise SIMILAR TO '[A-Z]{3}'),
    nom VARCHAR(100) NOT NULL CHECK (nom<>''),
    adresse VARCHAR(100) NOT NULL CHECK (adresse<>''),
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email<>''),
    mdp VARCHAR(100) NOT NULL
);

CREATE TABLE projet.etats (
    id_etat SERIAL PRIMARY KEY,
    etat VARCHAR(100) NOT NULL UNIQUE CHECK (etat<>'')
);

CREATE TABLE projet.mots_cles (
    id_mot_cle SERIAL PRIMARY KEY,
    mot VARCHAR(100) NOT NULL UNIQUE CHECK (mot<>'')
);

CREATE TABLE projet.offres_stage (
    id_offre_stage SERIAL PRIMARY KEY,
    code VARCHAR(5) NOT NULL UNIQUE CHECK ( code SIMILAR TO (offres_stage.entreprise || '\d')),
    entreprise CHAR(3) REFERENCES projet.entreprise(id_entreprise) NOT NULL,
    etat INTEGER REFERENCES projet.etats(id_etat) NOT NULL,
    etudiant INTEGER REFERENCES projet.etudiants(id_etudiant) NULL UNIQUE,
    nb_candidature INTEGER DEFAULT 0,
    semestre semestre NOT NULL,
    description VARCHAR(1000) NOT NULL
);

CREATE TABLE projet.candidatures (
    offre_stage INTEGER REFERENCES projet.offres_stage(id_offre_stage) NOT NULL,
    code_offre_stage VARCHAR(5) NOT NULL UNIQUE CHECK ( code_offre_stage SIMILAR TO (candidatures.offre_stage || '\d')),
    etudiant INTEGER REFERENCES projet.etudiants(id_etudiant) NOT NULL,
    CONSTRAINT candidatures_pk PRIMARY KEY (offre_stage, etudiant),
    etat INTEGER REFERENCES projet.etats(id_etat) NOT NULL,
    motivations VARCHAR(1000) NOT NULL
);

CREATE TABLE projet.offre_mot (
    offre_stage INTEGER REFERENCES projet.offres_stage(id_offre_stage) NOT NULL,
    mot_cle INTEGER REFERENCES projet.mots_cles(id_mot_cle) NOT NULL,
    CONSTRAINT offre_mot_pk PRIMARY KEY (offre_stage, mot_cle)
);



CREATE OR REPLACE FUNCTION get_offres_non_validees()
RETURNS TABLE (
    code VARCHAR(5),
    semestre semestre,
    entreprise_nom VARCHAR(100),
    description_etat VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT os.code, os.semestre, e.nom AS entreprise_nom, et.etat AS description_etat
    FROM projet.offres_stage os
    JOIN projet.etats et ON os.etat = et.id_etat
    JOIN projet.entreprise e ON os.entreprise = e.id_entreprise
    WHERE et.etat = 'non validée';
END;
$$ LANGUAGE plpgsql;

-- --encoder un étudiant pour prof
-- CREATE OR REPLACE FUNCTION encoder_etudiant(
--     e_nom VARCHAR(100),
--     e_prenom VARCHAR(100),
--     e_email VARCHAR(100),
--     e_semestre semestre,
--     e_mot_de_passe VARCHAR(100)
-- )
-- RETURNS VOID
-- AS $$
-- BEGIN
--     -- Vérifier si l'e-mail se termine par "@student.vinci.be"
--     IF position('@student.vinci.be' IN e_email) = 0 THEN
--         RAISE EXCEPTION 'L''adresse e-mail doit se terminer par "@student.vinci.be"';
--     END IF;
--
--     -- Insérer l'étudiant dans la table
--     INSERT INTO projet.etudiants (nom, prenom, email, semestre, mdp)
--     VALUES (e_nom, e_prenom, e_email, e_semestre, e_mot_de_passe);
-- END;
-- $$ LANGUAGE plpgsql;

--prof
CREATE OR REPLACE FUNCTION projet.encoder_etudiant(_nom VARCHAR(100), _prenom VARCHAR(100), _email VARCHAR(100), _semestre semestre, _mdp VARCHAR(100))
RETURNS VOID AS $$
BEGIN
    INSERT INTO projet.etudiants(nom, prenom, email, semestre, mdp) VALUES (_nom, _prenom, _email, _semestre, _mdp);
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projet.encoder_entreprise(_nom VARCHAR(100), _adresse VARCHAR(100), _email VARCHAR(100), _id CHAR(3), _mdp VARCHAR(100))
RETURNS VOID AS $$
BEGIN
    INSERT INTO projet.entreprise(id_entreprise, nom, adresse, email, mdp) VALUES (_id, _nom, _adresse, _email, _mdp);
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projet.encoder_mot_cle(p_mot VARCHAR(100))
RETURNS VOID
AS $$
BEGIN
    -- Insérer le mot-clé dans la table
    INSERT INTO projet.mots_cles (mot) VALUES (p_mot);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE VIEW projet.get_offres_non_validees AS
    SELECT os.code, os.semestre, e.nom AS entreprise_nom, et.etat AS description_etat
    FROM projet.offres_stage os
    JOIN projet.etats et ON os.etat = et.id_etat
    JOIN projet.entreprise e ON os.entreprise = e.id_entreprise
    WHERE et.etat = 'non validée';


CREATE OR REPLACE FUNCTION projet.valider_offre_stage(_code VARCHAR(5))
RETURNS VOID
AS $$
BEGIN
    UPDATE projet.offres_stage
    SET etat = (SELECT etat FROM projet.etats WHERE etat = 'validée')
    WHERE code = _code;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION valider_offre_stage_trigger()
RETURNS TRIGGER
AS $$
BEGIN
    IF (NEW.etat <> (SELECT etat FROM projet.etats WHERE etat = 'validée'))
    THEN
        RAISE 'ce stage ne peut pas etre validée';
    end if;
    RETURN NEW;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER valider_offre_stage_trigger BEFORE UPDATE ON projet.offres_stage
FOR EACH ROW
EXECUTE PROCEDURE valider_offre_stage_trigger ();


CREATE OR REPLACE VIEW projet.get_offres_validees AS
    SELECT os.code, os.semestre, e.nom AS entreprise_nom, et.etat AS description_etat
    FROM projet.offres_stage os
    JOIN projet.etats et ON os.etat = et.id_etat
    JOIN projet.entreprise e ON os.entreprise = e.id_entreprise
    WHERE et.etat = 'validée';


CREATE OR REPLACE VIEW projet.voir_etudiant_sans_stage AS
    SELECT DISTINCT et.nom, et.prenom, et.email, et.semestre, count(ca.*)
    FROM projet.etudiants et, projet.candidatures ca
    WHERE (ca.etudiant = et.id_etudiant)
    AND (et.id_etudiant NOT IN (
        SELECT et2.id_etudiant
        FROM projet.etudiants et2 LEFT OUTER JOIN projet.candidatures ca2 on et2.id_etudiant = ca2.etudiant
        WHERE (ca2.etat = 'acceptée')))
    GROUP BY et.nom, et.prenom, et.email, et.semestre;


CREATE OR REPLACE VIEW projet.voir_offre_stage_attribue AS
    SELECT os.code, en.nom, et.nom, et.prenom
    FROM projet.offres_stage os, projet.entreprise en, projet.etudiants et
    WHERE (os.entreprise = en.id_entreprise AND os.etudiant = et.id_etudiant)
    AND (os.etat = (SELECT etat FROM projet.etats WHERE etat = 'attribué'));


CREATE OR REPLACE FUNCTION projet.encoder_offre_stage(_description VARCHAR(1000), _semestre semestre, _entreprise CHAR(3))
RETURNS VOID AS $$
DECLARE
    numero_code INTEGER;
    etat_defaut INTEGER;
BEGIN
--     IF EXISTS (
--         SELECT os.* FROM projet.offres_stage os
--         WHERE (os.entreprise = _entreprise)
--         AND(os.semestre = _semestre)
--         AND (os.etat = (SELECT etat FROM projet.etats WHERE etats.etat = 'attribuée')))
--         THEN RAISE 'Offre de stage déjà attribuée durant ce semestre';
--     END IF;

    SELECT MAX(os.id_offre_stage)+1 FROM projet.offres_stage os WHERE (os.entreprise = _entreprise) INTO numero_code;
    SELECT et.id_etat FROM projet.etats et WHERE et.etat = 'non validée' INTO etat_defaut;

    INSERT INTO projet.offres_stage(code, entreprise, etat, semestre, description) VALUES (_entreprise+numero_code, _entreprise, etat_defaut, _semestre, _description);
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION encoder_offre_stage_trigger()
RETURNS TRIGGER
AS $$
BEGIN
    IF EXISTS (
        SELECT os.* FROM projet.offres_stage os
        WHERE (os.entreprise = NEW.entreprise)
        AND(os.semestre = NEW.semestre)
        AND (os.etat = (SELECT etat FROM projet.etats WHERE etats.etat = 'attribuée')))
        THEN RAISE 'Offre de stage déjà attribuée durant ce semestre';
    END IF;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER encoder_offre_stage_trigger BEFORE UPDATE ON projet.offres_stage
FOR EACH ROW
EXECUTE PROCEDURE encoder_offre_stage_trigger();


--entreprise: voir mot cle
--entreprise Q3  faut faire avec trigger faire après
/*CREATE OR REPLACE FUNCTION projet.ajouter_mot_cle_offre_stage(
    p_code_offre VARCHAR,
    p_mot_cle VARCHAR
)
RETURNS VOID
AS $$
DECLARE
    v_offre_id INTEGER;
    v_etat VARCHAR(100);
BEGIN
    -- Vérifier si l'offre de stage existe
    SELECT id_offre_stage, etat
    INTO v_offre_id, v_etat
    FROM projet.offres_stage
    WHERE code = p_code_offre;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aucune offre de stage trouvée avec le code spécifié.';
    END IF;

    -- Vérifier si l'offre de stage n'est pas dans un état invalide
    IF v_etat = 'attribuée' OR v_etat = 'annulée' THEN
        RAISE EXCEPTION 'Impossible d''ajouter un mot-clé à une offre dans l''état attribuée ou annulée.';
    END IF;

    -- Vérifier si l'offre de stage appartient à l'entreprise
    IF NOT EXISTS (
        SELECT 1
        FROM projet.offres_stage o
        JOIN projet.entreprise e ON o.entreprise = e.id_entreprise
        WHERE o.code = p_code_offre
    ) THEN
        RAISE EXCEPTION 'Impossible d''ajouter un mot-clé à une offre qui n''appartient pas à l''entreprise.';
    END IF;

    -- Vérifier si le mot-clé fait partie de la liste des mots-clés proposés
    IF NOT EXISTS (
        SELECT 1
        FROM projet.mots_cles mc
        WHERE mc.mot = p_mot_cle
    ) THEN
        RAISE EXCEPTION 'Le mot-clé spécifié n''est pas valide.';
    END IF;

    -- Vérifier si l'offre de stage a déjà atteint le nombre maximum de mots-clés
    IF (SELECT COUNT(*) FROM projet.offre_mot WHERE offre_stage = v_offre_id) >= 3 THEN
        RAISE EXCEPTION 'L''offre de stage a atteint le nombre maximum de mots-clés (3).';
    END IF;

    -- Ajouter le mot-clé à l'offre de stage
    INSERT INTO projet.offre_mot (offre_stage, mot_cle)
    VALUES (v_offre_id, (SELECT id_mot_cle FROM projet.mots_cles WHERE mot = p_mot_cle));

END;
$$ LANGUAGE plpgsql;*/

CREATE OR REPLACE FUNCTION projet.ajouter_mot_cle_offre_stage(_code_offre_stage VARCHAR(5), _mot_cle VARCHAR(100))
RETURNS VOID AS $$
DECLARE
    mot_cle_id INTEGER;
    offre_stage_id INTEGER;
    etat_attribuee INTEGER;
    etat_annulee INTEGER;
    etat_os INTEGER;
BEGIN
    SELECT id_offre_stage FROM projet.offres_stage WHERE (code = _code_offre_stage) INTO offre_stage_id;
    SELECT id_mot_cle FROM projet.mots_cles WHERE (mot = _mot_cle) INTO mot_cle_id;
    SELECT id_etat FROM projet.etats WHERE etat = 'attribuée' INTO etat_attribuee;
    SELECT id_etat FROM projet.etats WHERE etat = 'attribuée' INTO etat_annulee;
    SELECT os.etat FROM projet.offres_stage os WHERE (os.code = _code_offre_stage) INTO etat_os;
    IF (etat_os = etat_annulee OR etat_os = etat_attribuee)
        THEN RAISE 'Impossible d''ajouter un mot-clé à une offre dans l''état attribuée ou annulée';
    END IF;

    INSERT INTO projet.offre_mot(offre_stage, mot_cle) VALUES (offre_stage_id, mot_cle_id);
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ajouter_mot_cle_offre_stage_trigger()
RETURNS TRIGGER
AS $$
DECLARE
    mot_cle_count INTEGER;
BEGIN

    SELECT count(om.*) FROM projet.offre_mot om WHERE (om.offre_stage = NEW.offre_stage) INTO mot_cle_count;

    IF NOT EXISTS (
        SELECT os.* FROM projet.offres_stage os WHERE os.id_offre_stage = NEW.offre_stage
        )
    THEN RAISE 'Aucune offre de stage trouvée avec le code spécifié.';
    END IF;
    IF NOT EXISTS (
        SELECT mc.* FROM projet.mots_cles mc WHERE mc.id_mot_cle = NEW.mot_cle
        )
    THEN RAISE 'Le mot-clé spécifié n''est pas valide.';
    END IF;
    IF (mot_cle_count >=3)
        THEN RAISE 'L''offre de stage a atteint le nombre maximum de mots-clés (3).';
    END IF;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ajouter_mot_cle_offre_stage_trigger BEFORE UPDATE ON projet.offre_mot
FOR EACH ROW
EXECUTE PROCEDURE ajouter_mot_cle_offre_stage_trigger();

--entreprise: voir offre stage


CREATE OR REPLACE FUNCTION projet.voir_candidatures(_code_offre_stage VARCHAR(5), _entreprise CHAR(3))
RETURNS SETOF RECORD
AS $$
DECLARE
    sortie RECORD;
    candidatures_rec RECORD;
    id_entreprise CHAR(3);
BEGIN
    id_entreprise := SUBSTRING(_code_offre_stage FROM 1 FOR 3);
    IF id_entreprise != _entreprise
        THEN RAISE'Il n''y a pas de candidatures pour cette offre ou vous n''avez pas d''offre ayant ce code';
    END IF;
    IF NOT EXISTS(
        SELECT * FROM projet.offres_stage WHERE (projet.offres_stage.code=_code_offre_stage AND projet.offres_stage.entreprise = _entreprise)
        ) THEN RAISE 'Il n''y a pas de candidatures pour cette offre ou vous n''avez pas d''offre ayant ce code';
    END IF;
    IF NOT EXISTS(
        SELECT * FROM projet.candidatures WHERE (projet.candidatures.code_offre_stage = _code_offre_stage)
        ) THEN RAISE 'Il n''y a pas de candidatures pour cette offre ou vous n''avez pas d''offre ayant ce code';
    END IF;


    FOR candidatures_rec IN SELECT * FROM projet.candidatures WHERE (code_offre_stage = _code_offre_stage)
    LOOP
        SELECT ca.etat, et.nom, et.prenom, et.email, ca.motivations
        FROM candidatures_rec ca, projet.etudiants et
        WHERE (ca.etudiant = et.id_etudiant)
        AND(ca.code_offre_stage = _code_offre_stage)
        INTO sortie;
        RETURN NEXT sortie;
    END LOOP;
    RETURN;
end;
$$ LANGUAGE plpgsql;



--eleve
CREATE OR REPLACE FUNCTION incrementer_nb_candidature()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE projet.offres_stage
    SET nb_candidature = nb_candidature + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_nb_candidature AFTER INSERT ON projet.candidatures FOR EACH ROW
    EXECUTE PROCEDURE incrementer_nb_candidature();
