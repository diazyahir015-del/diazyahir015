param(
  [Parameter(Mandatory = $true)]
  [string]$Name
)

$ErrorActionPreference = 'Stop'

function Require-Command([string]$CommandName) {
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "Error: '$CommandName' no está instalado."
  }
}

Require-Command node
Require-Command npm

$RootDir = Join-Path (Get-Location) $Name
$BackendDir = Join-Path $RootDir 'backend'
$FrontendDir = Join-Path $RootDir 'frontend'

New-Item -ItemType Directory -Force -Path $RootDir, "$BackendDir/src/config", "$BackendDir/src/models", "$BackendDir/src/routes", "$BackendDir/src/scripts" | Out-Null

@'
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
'@ | Set-Content -Path "$BackendDir/package.json" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$BackendDir/.env.example" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$BackendDir/src/config/db.js" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$BackendDir/src/models/User.js" -Encoding UTF8

@'
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
  } catch (_error) {
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
  } catch (_error) {
    return res.status(500).json({ message: 'Error interno al iniciar sesión' });
  }
});

module.exports = router;
'@ | Set-Content -Path "$BackendDir/src/routes/users.js" -Encoding UTF8

@'
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
    Write-Host '✅ Conexión a BD correcta';

    app.listen(port, () => {
      Write-Host "✅ Backend corriendo en http://localhost:$port";
    });
  } catch (error) {
    Write-Host "❌ Error al iniciar backend: $($error.Message)";
    process.exit(1);
  }
};

start();
'@ | Set-Content -Path "$BackendDir/src/index.js" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$BackendDir/src/scripts/migrate.js" -Encoding UTF8

@'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4000
CMD ["npm", "run", "dev"]
'@ | Set-Content -Path "$BackendDir/Dockerfile" -Encoding UTF8

if (-not (Test-Path "$FrontendDir/package.json")) {
  npm create vite@latest $FrontendDir -- --template react | Out-Null
}

Push-Location $FrontendDir
npm install | Out-Null
npm install -D tailwindcss postcss autoprefixer | Out-Null
if (-not (Test-Path 'tailwind.config.js')) {
  npx tailwindcss init -p | Out-Null
}

@'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {}
  },
  plugins: []
};
'@ | Set-Content -Path "$FrontendDir/tailwind.config.js" -Encoding UTF8

@'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-slate-100 text-slate-900;
}
'@ | Set-Content -Path "$FrontendDir/src/index.css" -Encoding UTF8

@'
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
          <input className="w-full rounded border p-2" name="name" placeholder="Nombre" value={form.name} onChange={onChange} required />
          <input className="w-full rounded border p-2" type="email" name="email" placeholder="Correo" value={form.email} onChange={onChange} required />
          <input className="w-full rounded border p-2" type="password" name="password" placeholder="Contraseña (mínimo 8 caracteres)" value={form.password} onChange={onChange} required />
          <button className="rounded bg-blue-600 px-4 py-2 font-semibold text-white hover:bg-blue-700" type="submit">Crear cuenta</button>
        </form>

        <p className="mt-4 text-sm">{message}</p>
      </section>
    </main>
  );
}
'@ | Set-Content -Path "$FrontendDir/src/App.jsx" -Encoding UTF8

@'
VITE_API_URL=http://localhost:4000
'@ | Set-Content -Path "$FrontendDir/.env.example" -Encoding UTF8

Pop-Location

@'
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
'@ | Set-Content -Path "$RootDir/docker-compose.yml" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$RootDir/.gitignore" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$RootDir/README.md" -Encoding UTF8

@'
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
'@ | Set-Content -Path "$RootDir/NEXT_STEPS.txt" -Encoding UTF8

Push-Location $BackendDir
npm install | Out-Null
Pop-Location

Write-Host "✅ Scaffold creado en: $RootDir"
