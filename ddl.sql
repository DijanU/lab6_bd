-- Eliminación previa por si existe
DROP TABLE IF EXISTS Adopciones, Tratamientos, Animales, Especies, Personas, Empleados, Veterinarios CASCADE;

-- Tabla: Especies
CREATE TABLE Especies (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

-- Tabla: Personas (para adoptantes y donantes)
CREATE TABLE Personas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(15) UNIQUE,
    email VARCHAR(100) UNIQUE,
    direccion TEXT NOT NULL
);

-- Tabla: Empleados (administradores o cuidadores)
CREATE TABLE Empleados (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puesto VARCHAR(50) CHECK (puesto IN ('Cuidador', 'Administrador', 'Voluntario')),
    fecha_ingreso DATE NOT NULL
);

-- Tabla: Veterinarios
CREATE TABLE Veterinarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    colegiado VARCHAR(20) UNIQUE NOT NULL,
    especialidad VARCHAR(100)
);

-- Tabla: Animales
CREATE TABLE Animales (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    especie_id INTEGER REFERENCES Especies(id),
    edad INTEGER NOT NULL CHECK (edad >= 0),
    fecha_ingreso DATE NOT NULL,
    salud VARCHAR(20) NOT NULL CHECK (salud IN ('Buena', 'Regular', 'Crítica')),
    adoptado BOOLEAN DEFAULT FALSE,
    UNIQUE (nombre, fecha_ingreso)
);

-- Tabla: Adopciones
CREATE TABLE Adopciones (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER UNIQUE REFERENCES Animales(id),
    persona_id INTEGER REFERENCES Personas(id),
    fecha_adopcion DATE NOT NULL,
    aprobado_por INTEGER REFERENCES Empleados(id)
);

-- Tabla: Tratamientos
CREATE TABLE Tratamientos (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES Animales(id),
    veterinario_id INTEGER REFERENCES Veterinarios(id),
    descripcion TEXT NOT NULL,
    fecha DATE NOT NULL,
    costo NUMERIC(8, 2) CHECK (costo >= 0)
);
