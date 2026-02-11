#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: ./scaffold.sh <nombre-proyecto>"
  exit 1
fi

PROJECT_NAME="$1"
ROOT_DIR="$(pwd)/$PROJECT_NAME"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: '$1' no está instalado."
    exit 1
  }
}

require_cmd node
require_cmd npm

mkdir -p "$ROOT_DIR" "$BACKEND_DIR/src/config" "$BACKEND_DIR/src/models" "$BACKEND_DIR/src/routes" "$BACKEND_DIR/src/scripts"

cat > "$BACKEND_DIR/package.json" <<'JSON'
{
  "name": "backend",
  "version": "1.0.0",
  "private": true,
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "migrate": "node src/scripts/migrate.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "jsonwebtoken": "^9.0.2",
    "mysql2": "^3.11.0",
    "pg": "^8.12.0",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.37.3"
  },
  "devDependencies": {
    "nodemon": "^3.1.4"
  }
}
JSON

cat > "$BACKEND_DIR/.env.example" <<'ENV'
PORT=4000
NODE_ENV=development
DB_DIALECT=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=app_db
DB_USER=app_user
DB_PASSWORD=app_password_change_me
JWT_SECRET=change_this_super_secret_jwt_value
CORS_ORIGIN=http://localhost:5173
ENV

cat > "$BACKEND_DIR/src/config/db.js" <<'EOF_DB'
const { Sequelize } = require('sequelize');
require('dotenv').config();

const {
  DB_DIALECT = 'mysql',
  DB_HOST = 'localhost',
  DB_PORT = DB_DIALECT === 'postgres' ? '5432' : '3306',
  DB_NAME = 'app_db',
  DB_USER = 'app_user',
  DB_PASSWORD = ''
} = process.env;

const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
  host: DB_HOST,
  port: Number(DB_PORT),
  dialect: DB_DIALECT,
  logging: false
});

module.exports = sequelize;
EOF_DB

cat > "$BACKEND_DIR/src/models/User.js" <<'EOF_USER'
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const User = sequelize.define(
  'User',
  {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true
    },
    name: {
      type: DataTypes.STRING(120),
      allowNull: false
    },
    email: {
      type: DataTypes.STRING(160),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      }
    },
    passwordHash: {
      type: DataTypes.STRING,
      allowNull: false
    }
  },
  {
    tableName: 'users',
    timestamps: true
  }
);

module.exports = User;
EOF_USER

cat > "$BACKEND_DIR/src/routes/users.js" <<'EOF_ROUTES'
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'name, email y password son obligatorios' });
    }

    if (password.length < 8) {
      return res.status(400).json({ message: 'La contraseña debe tener al menos 8 caracteres' });
    }

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({ message: 'El correo ya está registrado' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({ name, email, passwordHash });

    return res.status(201).json({
      message: 'Usuario registrado correctamente',
      user: { id: user.id, name: user.name, email: user.email }
    });
  } catch (error) {
    return res.status(500).json({ message: 'Error interno al registrar usuario' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'email y password son obligatorios' });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({ message: 'Credenciales inválidas' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ message: 'Credenciales inválidas' });
    }

    const token = jwt.sign(
      { sub: user.id, email: user.email },
      process.env.JWT_SECRET || 'change_this_secret',
      { expiresIn: '1d' }
    );

    return res.json({
      message: 'Login correcto',
      token,
      user: { id: user.id, name: user.name, email: user.email }
    });
  } catch (error) {
    return res.status(500).json({ message: 'Error interno al iniciar sesión' });
  }
});

module.exports = router;
EOF_ROUTES

cat > "$BACKEND_DIR/src/index.js" <<'EOF_INDEX'
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const sequelize = require('./config/db');
const usersRoutes = require('./routes/users');

const app = express();
const port = process.env.PORT || 4000;

app.use(cors({ origin: process.env.CORS_ORIGIN || 'http://localhost:5173' }));
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/users', usersRoutes);

const start = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Conexión a BD correcta');

    app.listen(port, () => {
      console.log(`✅ Backend corriendo en http://localhost:${port}`);
    });
  } catch (error) {
    console.error('❌ Error al iniciar backend:', error.message);
    process.exit(1);
  }
};

start();
EOF_INDEX

cat > "$BACKEND_DIR/src/scripts/migrate.js" <<'EOF_MIG'
require('dotenv').config();
const sequelize = require('../config/db');
require('../models/User');

(async () => {
  try {
    await sequelize.sync({ alter: true });
    console.log('✅ Migración completada: tablas creadas/actualizadas');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error en migración:', error.message);
    process.exit(1);
  }
})();
EOF_MIG

cat > "$BACKEND_DIR/Dockerfile" <<'EOF_DOCKER'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4000
CMD ["npm", "run", "dev"]
EOF_DOCKER

if [[ ! -d "$FRONTEND_DIR" ]]; then
  npm create vite@latest "$FRONTEND_DIR" -- --template react >/dev/null
fi

cd "$FRONTEND_DIR"
npm install >/dev/null
npm install -D tailwindcss postcss autoprefixer >/dev/null
if [[ ! -f tailwind.config.js ]]; then
  npx tailwindcss init -p >/dev/null
fi

cat > "$FRONTEND_DIR/tailwind.config.js" <<'EOF_TW'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {}
  },
  plugins: []
};
EOF_TW

cat > "$FRONTEND_DIR/src/index.css" <<'EOF_CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-slate-100 text-slate-900;
}
EOF_CSS

cat > "$FRONTEND_DIR/src/App.jsx" <<'EOF_APP'
import { useState } from 'react';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000';

export default function App() {
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [message, setMessage] = useState('');

  const onChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const onSubmit = async (e) => {
    e.preventDefault();
    setMessage('Enviando...');

    try {
      const response = await fetch(`${API_URL}/api/users/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      const data = await response.json();
      setMessage(data.message || 'Proceso completado');
    } catch (_error) {
      setMessage('No se pudo conectar al backend');
    }
  };

  return (
    <main className="min-h-screen p-6">
      <section className="mx-auto max-w-xl rounded-xl bg-white p-6 shadow">
        <h1 className="mb-2 text-2xl font-bold">Registro de usuario</h1>
        <p className="mb-6 text-sm text-slate-600">Formulario conectado al endpoint de backend.</p>

        <form className="space-y-4" onSubmit={onSubmit}>
          <input
            className="w-full rounded border p-2"
            name="name"
            placeholder="Nombre"
            value={form.name}
            onChange={onChange}
            required
          />
          <input
            className="w-full rounded border p-2"
            type="email"
            name="email"
            placeholder="Correo"
            value={form.email}
            onChange={onChange}
            required
          />
          <input
            className="w-full rounded border p-2"
            type="password"
            name="password"
            placeholder="Contraseña (mínimo 8 caracteres)"
            value={form.password}
            onChange={onChange}
            required
          />
          <button className="rounded bg-blue-600 px-4 py-2 font-semibold text-white hover:bg-blue-700" type="submit">
            Crear cuenta
          </button>
        </form>

        <p className="mt-4 text-sm">{message}</p>
      </section>
    </main>
  );
}
EOF_APP

if ! grep -q "VITE_API_URL" "$FRONTEND_DIR/.env.example" 2>/dev/null; then
  cat > "$FRONTEND_DIR/.env.example" <<'EOF_FENV'
VITE_API_URL=http://localhost:4000
EOF_FENV
fi

cd "$ROOT_DIR"

cat > "docker-compose.yml" <<'EOF_DC'
version: '3.9'
services:
  db:
    image: mysql:8.0
    container_name: app_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root_change_me
      MYSQL_DATABASE: app_db
      MYSQL_USER: app_user
      MYSQL_PASSWORD: app_password_change_me
    ports:
      - '3306:3306'
    volumes:
      - db_data:/var/lib/mysql

  backend:
    build: ./backend
    container_name: app_backend
    restart: unless-stopped
    env_file:
      - ./backend/.env
    ports:
      - '4000:4000'
    depends_on:
      - db
    volumes:
      - ./backend:/app
      - /app/node_modules

  frontend:
    image: node:18-alpine
    container_name: app_frontend
    restart: unless-stopped
    working_dir: /app
    command: sh -c "npm install && npm run dev -- --host 0.0.0.0 --port 5173"
    ports:
      - '5173:5173'
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules

volumes:
  db_data:
EOF_DC

cat > ".gitignore" <<'EOF_GI'
node_modules/
.env
.env.*
!.env.example
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
dist/
coverage/
*.log
.DS_Store
.vscode/
EOF_GI

cat > "README.md" <<'EOF_README'
# Fullstack Scaffold (Express + Sequelize + MySQL + React + Vite + Tailwind)

Este proyecto se crea automáticamente con `scaffold.sh` o `scaffold.ps1`.

## Estructura

- `backend/`: API Express con Sequelize y autenticación básica (JWT).
- `frontend/`: App React con Vite y Tailwind.
- `docker-compose.yml`: Orquesta base de datos MySQL + backend + frontend.

## Ejecución rápida

1. Copia variables de entorno:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Ajusta valores en `.env` (sobre todo `JWT_SECRET` y credenciales de BD).
3. Con Docker:
   - `docker-compose up --build`
4. Sin Docker:
   - Backend: `cd backend && npm install && npm run migrate && npm run dev`
   - Frontend: `cd frontend && npm install && npm run dev`

## Endpoints

- `POST /api/users/register`
- `POST /api/users/login`

Consulta `NEXT_STEPS.txt` para guía detallada y checklist.
EOF_README

cat > "NEXT_STEPS.txt" <<'EOF_NEXT'
GUÍA PASO A PASO
================

1) Variables de entorno
-----------------------
- Backend:
  cp backend/.env.example backend/.env
- Frontend:
  cp frontend/.env.example frontend/.env

Cambia al menos:
- backend/.env -> JWT_SECRET (usa un valor largo y único)
- backend/.env -> DB_HOST, DB_USER, DB_PASSWORD, DB_NAME
- frontend/.env -> VITE_API_URL (ej. http://localhost:4000)

2) Migraciones
--------------
- En backend ejecuta:
  npm run migrate
Esto crea/actualiza la tabla `users`.

3) Levantar con Docker
----------------------
- Comando:
  docker-compose up --build
- URLs:
  Frontend: http://localhost:5173
  Backend: http://localhost:4000/api/health

4) Levantar sin Docker
----------------------
Backend:
  cd backend
  npm install
  npm run migrate
  npm run dev

Frontend (en otra terminal):
  cd frontend
  npm install
  npm run dev

5) Probar endpoints con curl
----------------------------
Registro:
  curl -X POST http://localhost:4000/api/users/register \
    -H "Content-Type: application/json" \
    -d '{"name":"Ana","email":"ana@example.com","password":"Password123"}'

Login:
  curl -X POST http://localhost:4000/api/users/login \
    -H "Content-Type: application/json" \
    -d '{"email":"ana@example.com","password":"Password123"}'

6) Conectar frontend con backend
--------------------------------
- Archivo: frontend/src/App.jsx
- Variable: API_URL (usa VITE_API_URL).
- Si cambias puerto o dominio del backend, actualiza frontend/.env.

6 acciones mínimas antes de producción
--------------------------------------
1. Cambiar JWT_SECRET por uno robusto y único.
2. No usar contraseñas por defecto en BD ni usuarios genéricos.
3. Habilitar HTTPS con certificado válido.
4. Configurar backups automáticos de base de datos.
5. Activar logs estructurados y monitoreo de errores.
6. Gestionar variables sensibles con un vault o entorno seguro.

Mejoras siguientes
------------------
- Integrar pagos (Stripe o Mercado Pago en modo sandbox).
- Generar PDF de comprobantes/facturas.
- Agregar pruebas unitarias e integración (Jest + Supertest / Vitest).
EOF_NEXT

cd "$BACKEND_DIR"
npm install >/dev/null

echo "✅ Scaffold creado en: $ROOT_DIR"
