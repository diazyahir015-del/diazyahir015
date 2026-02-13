const express = require('express');
const fs = require('fs/promises');
const path = require('path');

const app = express();
const PORT = 3000;
const USERS_DB_PATH = path.join(__dirname, 'database', 'users.json');

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

async function ensureUsersDb() {
  try {
    await fs.access(USERS_DB_PATH);
  } catch {
    await fs.mkdir(path.dirname(USERS_DB_PATH), { recursive: true });
    await fs.writeFile(USERS_DB_PATH, '[]', 'utf-8');
  }
}

async function readUsers() {
  await ensureUsersDb();
  const data = await fs.readFile(USERS_DB_PATH, 'utf-8');
  return JSON.parse(data);
}

async function writeUsers(users) {
  await fs.writeFile(USERS_DB_PATH, JSON.stringify(users, null, 2), 'utf-8');
}

function validateRegistration({ fullName, email, password }) {
  if (!fullName || fullName.trim().length < 3) {
    return 'El nombre debe tener al menos 3 caracteres.';
  }

  if (!email || !/^\S+@\S+\.\S+$/.test(email)) {
    return 'Ingresa un correo electrónico válido.';
  }

  if (!password || password.length < 6) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }

  return null;
}

app.post('/api/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    const validationError = validateRegistration({ fullName, email, password });

    if (validationError) {
      return res.status(400).json({ ok: false, message: validationError });
    }

    const users = await readUsers();
    const existingUser = users.find((user) => user.email.toLowerCase() === email.toLowerCase());

    if (existingUser) {
      return res.status(409).json({ ok: false, message: 'Este correo ya está registrado.' });
    }

    const newUser = {
      id: Date.now(),
      fullName: fullName.trim(),
      email: email.toLowerCase(),
      password,
      createdAt: new Date().toISOString()
    };

    users.push(newUser);
    await writeUsers(users);

    return res.status(201).json({
      ok: true,
      message: 'Registro exitoso.',
      user: {
        id: newUser.id,
        fullName: newUser.fullName,
        email: newUser.email
      }
    });
  } catch (error) {
    return res.status(500).json({ ok: false, message: 'Error interno del servidor.' });
  }
});

app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ ok: false, message: 'Correo y contraseña son obligatorios.' });
    }

    const users = await readUsers();
    const user = users.find((item) => item.email.toLowerCase() === email.toLowerCase());

    if (!user || user.password !== password) {
      return res.status(401).json({ ok: false, message: 'Credenciales inválidas.' });
    }

    return res.json({
      ok: true,
      message: 'Inicio de sesión exitoso.',
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email
      }
    });
  } catch (error) {
    return res.status(500).json({ ok: false, message: 'Error interno del servidor.' });
  }
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'DC Nexus Pro', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`DC Nexus Pro ejecutándose en http://localhost:${PORT}`);
});
