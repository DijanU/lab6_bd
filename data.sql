-- Especies
INSERT INTO Especies (nombre) VALUES
('Perro'), ('Gato'), ('Conejo'), ('Ave'), ('Tortuga');

-- Personas
DO $$
BEGIN
  FOR i IN 1..60 LOOP
    INSERT INTO Personas (nombre, telefono, email, direccion)
    VALUES (
      'Persona ' || i,
      '555-010' || i,
      'persona' || i || '@ejemplo.com',
      'Dirección ' || i
    );
  END LOOP;
END $$;

-- Empleados
INSERT INTO Empleados (nombre, puesto, fecha_ingreso) VALUES
('Carlos López', 'Cuidador', '2022-03-15'),
('Ana Martínez', 'Administrador', '2021-07-20'),
('Luis Pérez', 'Cuidador', '2023-01-10'),
('María González', 'Voluntario', '2024-01-05');

-- Veterinarios
INSERT INTO Veterinarios (nombre, colegiado, especialidad) VALUES
('Dra. Sandra Ruiz', 'VET001', 'Pequeñas especies'),
('Dr. Jorge Velásquez', 'VET002', 'Cirugía animal'),
('Dra. Lucía Robles', 'VET003', 'Rehabilitación');

-- Animales
DO $$
DECLARE
  especies_id INTEGER[];
  saludes TEXT[] := ARRAY['Buena', 'Regular', 'Crítica'];
BEGIN
  SELECT array_agg(id) INTO especies_id FROM Especies;
  
  FOR i IN 1..60 LOOP
    INSERT INTO Animales (nombre, especie_id, edad, fecha_ingreso, salud)
    VALUES (
      'Animal ' || i,
      especies_id[1 + (random() * (array_length(especies_id, 1) - 1))::int],
      (random() * 10)::int,
      CURRENT_DATE - ((random() * 100)::int || ' days')::interval,
      saludes[1 + (random() * 2)::int]
    );
  END LOOP;
END $$;

-- Adopciones
-- Solo algunos animales son adoptados (por ejemplo, los primeros 20)
INSERT INTO Adopciones (animal_id, persona_id, fecha_adopcion, aprobado_por)
SELECT a.id, p.id, CURRENT_DATE - ((random() * 30)::int || ' days')::interval, 1
FROM Animales a
JOIN Personas p ON p.id <= 20
WHERE a.id <= 20;

-- Actualizar animales como adoptados
UPDATE Animales SET adoptado = TRUE WHERE id IN (SELECT animal_id FROM Adopciones);

-- Tratamientos
INSERT INTO Tratamientos (animal_id, veterinario_id, descripcion, fecha, costo)
SELECT a.id, (1 + (random() * 2)::int), 
       'Tratamiento para condición médica ' || a.id,
       CURRENT_DATE - ((random() * 50)::int || ' days')::interval,
       (random() * 500)::numeric(8, 2)
FROM Animales a
WHERE a.salud != 'Buena'
LIMIT 30;
