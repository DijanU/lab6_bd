-- 3 Funciones

-- 1. Valor escalar
-- Calcula el tiempo promedio de adopcion en el refugio para
-- cualquier animal
CREATE OR REPLACE FUNCTION promedio_tiempo_adopcion()
RETURNS NUMERIC AS $$
DECLARE
    total_days NUMERIC := 0;
    adoption_count INTEGER := 0;
BEGIN
    SELECT 
        SUM(a.fecha_adopcion - ani.fecha_ingreso),
        COUNT(*)
    INTO 
        total_days,
        adoption_count
    FROM 
        Adopciones a
        JOIN Animales ani ON a.animal_id = ani.id
    WHERE 
        a.fecha_adopcion IS NOT NULL;
    
    IF adoption_count = 0 THEN
        RETURN NULL;
    ELSE
        RETURN ROUND(total_days::NUMERIC / adoption_count, 2);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Logica condicional
-- Verifica que un animal pueda ser adoptado, verifica que
-- la fila de 'adoptado' sea falsa y no se encuentre en salud
-- critica.
CREATE OR REPLACE FUNCTION animal_puede_ser_adoptado(
    p_animal_id INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_animal RECORD;
BEGIN
    SELECT adoptado, salud INTO v_animal
    FROM Animales 
    WHERE id = p_animal_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    RETURN (
        v_animal.adoptado = FALSE AND
        v_animal.salud != 'Crítica'
    );
END;
$$ LANGUAGE plpgsql;

-- 3. Conjunto de resultados
-- Regresa un listado de animales disponibles para adopcion filtrado
-- por el ID de la especie. Utiliza una funcion que definimos antes
-- para calcular la elegibilidad del animal.
CREATE OR REPLACE FUNCTION animales_disponibles_adopcion(
    p_especie_id INT DEFAULT NULL
) RETURNS TABLE (
    animal_id INTEGER,
    animal_nombre VARCHAR,
    especie VARCHAR,
    edad INTEGER,
    salud VARCHAR,
    dias_en_refugio INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id AS animal_id,
        a.nombre AS animal_nombre,
        e.nombre AS especie,
        a.edad,
        a.salud,
        (CURRENT_DATE - a.fecha_ingreso)::INTEGER AS dias_en_refugio
    FROM 
        Animales a
        JOIN Especies e ON a.especie_id = e.id
    WHERE 
        animal_puede_ser_adoptado(a.id) AND
        (p_especie_id IS NULL OR a.especie_id = p_especie_id)
    ORDER BY 
        a.fecha_ingreso ASC;
END;
$$ LANGUAGE plpgsql;

-- 2 Procedimientos Almacenados

-- 1. Para inserciones complejas
-- Registra una adopcion, primero verifica que todos los valores
-- sean validos y el animal pueda ser adoptado. Luego, 1 mes despues
-- se programa una cita post-adopcion.
CREATE OR REPLACE PROCEDURE registrar_adopcion(
    p_animal_id INTEGER,
    p_persona_id INTEGER,
    p_empleado_id INTEGER,
    p_fecha_adopcion DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_persona_existe BOOLEAN;
    v_empleado_valido BOOLEAN;
    v_animal_especie TEXT;
    v_veterinario_id INTEGER;
BEGIN
    SELECT EXISTS(SELECT 1 FROM Personas WHERE id = p_persona_id) INTO v_persona_existe;
    IF NOT v_persona_existe THEN
        RAISE EXCEPTION 'La persona no existe';
    END IF;
    
    SELECT EXISTS(
        SELECT 1 FROM Empleados 
        WHERE id = p_empleado_id AND puesto = 'Administrador'
    ) INTO v_empleado_valido;
    
    IF NOT v_empleado_valido THEN
        RAISE EXCEPTION 'Solo administradores pueden aprobar adopciones';
    END IF;

    INSERT INTO Adopciones (
        animal_id,
        persona_id,
        fecha_adopcion,
        aprobado_por
    ) VALUES (
        p_animal_id,
        p_persona_id,
        p_fecha_adopcion,
        p_empleado_id
    );
    
    SELECT e.nombre INTO v_animal_especie
    FROM Animales a
    JOIN Especies e ON a.especie_id = e.id
    WHERE a.id = p_animal_id;

    SELECT id INTO v_veterinario_id
    FROM Veterinarios
    LIMIT 1;
    
    UPDATE Animales SET adoptado = TRUE WHERE id = p_animal_id;
    
    INSERT INTO Tratamientos (
        animal_id,
        veterinario_id,
        descripcion,
        fecha,
        costo
    ) VALUES (
        p_animal_id,
        v_veterinario_id,
        'Control post-adopción - ' || v_animal_especie,
        p_fecha_adopcion + INTERVAL '1 month',
        0.00
    );
    
    RAISE NOTICE 'Adopción registrada exitosamente. ID Animal: %, ID Persona: %', p_animal_id, p_persona_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al registrar adopción: %', SQLERRM;
END;
$$;

-- 2. Para updates / deletes con validaciones
-- Posiblemente el store procedure mas triste en la historia de Postgres,
-- remueve las adopciones por si devuelven a algun animalito. Quita
-- las adopciones y remueve la cita de control post-adopcion
CREATE OR REPLACE PROCEDURE eliminar_adopcion(
    p_adopcion_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_adopcion RECORD;
BEGIN
    SELECT * INTO v_adopcion FROM Adopciones WHERE id = p_adopcion_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La adopción no existe';
    END IF;

    IF CURRENT_DATE > (v_adopcion.fecha_adopcion + INTERVAL '30 days') THEN
        RAISE EXCEPTION 'La adopcion no puede ser eliminada, han pasado mas de 30 dias';
    END IF;

    DELETE FROM Adopciones WHERE id = p_adopcion_id;

    RAISE NOTICE 'Adopción eliminada exitosamente. ID Adopción: %', p_adopcion_id;
END;
$$;

-- 4 Vistas

-- 1. Vista simple
-- Visualiza los animales que pueden ser adoptados
CREATE OR REPLACE VIEW vista_animales_disponibles AS
SELECT 
    a.id,
    a.nombre AS nombre_animal,
    e.nombre AS especie,
    a.edad,
    a.salud,
    a.fecha_ingreso,
    (CURRENT_DATE - a.fecha_ingreso) AS dias_en_refugio
FROM 
    Animales a
JOIN 
    Especies e ON a.especie_id = e.id
WHERE 
    animal_puede_ser_adoptado(a.id)
ORDER BY 
    a.fecha_ingreso ASC;

-- 2. Join y group by
-- Visualiza estadisticas de adopcion por especie, join en animales
-- y adopciones
CREATE OR REPLACE VIEW vista_estadisticas_adopcion_especie AS
SELECT 
    e.nombre AS especie,
    COUNT(a.id) AS total_animales,
    COUNT(ad.id) AS total_adoptados,
    ROUND(COUNT(ad.id) * 100.0 / NULLIF(COUNT(a.id), 0), 2) AS porcentaje_adopcion,
    COALESCE(AVG(ad.fecha_adopcion - a.fecha_ingreso), 0) AS promedio_dias_para_adopcion
FROM 
    Especies e
LEFT JOIN 
    Animales a ON e.id = a.especie_id
LEFT JOIN 
    Adopciones ad ON a.id = ad.animal_id
GROUP BY 
    e.nombre
ORDER BY 
    porcentaje_adopcion DESC;

-- 3. Expresion CASE y COALESCE
-- Visualiza los animales con un breve historial
-- de sus tratamientos y quienes los han tratado
CREATE OR REPLACE VIEW vista_historial_animales AS
SELECT 
    a.id,
    a.nombre AS nombre_animal,
    e.nombre AS especie,
    a.edad,
    a.salud,
    (CURRENT_DATE - a.fecha_ingreso) AS dias_en_refugio,
    COALESCE(COUNT(t.id), 0) AS total_tratamientos,
    COALESCE(SUM(t.costo), 0) AS costo_total_tratamientos,
    COALESCE(MAX(t.fecha), a.fecha_ingreso) AS ultimo_tratamiento,
    COALESCE(
        (SELECT descripcion 
         FROM Tratamientos 
         WHERE animal_id = a.id 
         ORDER BY fecha DESC 
         LIMIT 1),
        'Sin tratamientos'
    ) AS ultimo_tratamiento_descripcion,
    CASE 
        WHEN a.adoptado THEN 'Adoptado'
        WHEN NOT animal_puede_ser_adoptado(a.id) THEN 'No disponible'
        ELSE 'Disponible'
    END AS estado_adopcion,
    COALESCE(
        (SELECT string_agg(v.nombre, ', ') 
         FROM Tratamientos t2
         JOIN Veterinarios v ON t2.veterinario_id = v.id
         WHERE t2.animal_id = a.id),
        'Sin veterinarios asignados'
    ) AS veterinarios_que_lo_trataron
FROM 
    Animales a
JOIN 
    Especies e ON a.especie_id = e.id
LEFT JOIN 
    Tratamientos t ON a.id = t.animal_id
GROUP BY 
    a.id, e.nombre, a.adoptado, a.fecha_ingreso
ORDER BY 
    a.salud DESC, dias_en_refugio DESC;


-- 4. Adicional para llegar a las 4 views
-- Ofrece informacion sobre los veterinarios, cada uno
-- cobra el 20% del costo real de la operacion por ser
-- un refugio. Imprime estadisticas como promedio, total, etc.
CREATE OR REPLACE VIEW vet_payment_summary AS
SELECT 
    v.nombre AS vet_name,
    COUNT(t.id) AS procedures_done,
    SUM(t.costo) AS total_procedure_cost,
    ROUND(SUM(t.costo) * 0.20, 2) AS vet_payout,
    ROUND(AVG(t.costo), 2) AS avg_procedure_cost,
    ROUND(AVG(t.costo) * 0.20, 2) AS avg_payout_per_procedure
FROM 
    Veterinarios v
LEFT JOIN 
    Tratamientos t ON v.id = t.veterinario_id
GROUP BY 
    v.id, v.nombre
ORDER BY 
    vet_payout DESC;

-- Triggers

-- 1. Before
-- Verifica que el animal pueda ser adoptado antes de insertar
-- en adopciones, utiliza la logica de una funcion definida anteriormente
CREATE OR REPLACE FUNCTION check_animal_adoptable_before_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT animal_puede_ser_adoptado(NEW.animal_id) THEN
        RAISE EXCEPTION 'El animal no está disponible para adopción';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_check_animal_adoptable
BEFORE INSERT ON Adopciones
FOR EACH ROW
EXECUTE FUNCTION check_animal_adoptable_before_insert();

-- 2. After delete
-- Luego de eliminar una adopcion, revierte el estado
-- del animal y remueve su cita post adopcion
CREATE OR REPLACE FUNCTION after_delete_adopcion_trigger()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Animales 
    SET adoptado = FALSE 
    WHERE id = OLD.animal_id;

    DELETE FROM Tratamientos
    WHERE animal_id = OLD.animal_id
      AND descripcion LIKE 'Control post-adopción%';

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_after_delete_adopcion
AFTER DELETE ON Adopciones
FOR EACH ROW
EXECUTE FUNCTION after_delete_adopcion_trigger();
