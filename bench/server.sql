-- B: the same two functions in the server's other languages.
CREATE OR REPLACE FUNCTION steps_plpgsql(n bigint) RETURNS bigint LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE x bigint := n; k bigint := 0;
BEGIN
    WHILE x <> 1 LOOP
        IF x % 2 = 0 THEN x := x / 2; ELSE x := 3 * x + 1; END IF;
        k := k + 1;
    END LOOP;
    RETURN k;
END $$;

CREATE OR REPLACE FUNCTION vowels_plpgsql(s text) RETURNS bigint LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE k bigint := 0; i int; c text;
BEGIN
    FOR i IN 1..length(s) LOOP
        c := substr(s, i, 1);
        IF c IN ('a', 'e', 'i', 'o', 'u') THEN k := k + 1; END IF;
    END LOOP;
    RETURN k;
END $$;

-- The SQL builtin that does the vowel count in one expression: the floor for strings.
CREATE OR REPLACE FUNCTION vowels_sql(s text) RETURNS bigint LANGUAGE sql IMMUTABLE STRICT
    AS $$ SELECT length(s) - length(translate(s, 'aeiou', '')) $$;
