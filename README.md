# DC Nexus Pro

Sistema web completo con frontend empresarial, backend en Node.js/Express y base de datos JSON para registro e inicio de sesión.

## Ejecutar en local

```bash
npm install
node server.js
```

Abrir en el navegador:

- `http://localhost:3000`

## Funciones principales

- Landing profesional con múltiples secciones (documentos, proceso, beneficios, contacto).
- Selector de trámites para documentos como Acta de nacimiento y CURP.
- Formulario dinámico por tipo de documento en `document-form.html`.
- Registro, login y dashboard de usuario.

## Estructura

- `server.js`: API + servidor estático.
- `database/users.json`: base de datos simple de usuarios.
- `public/`: frontend (`index`, `document-form`, `login`, `register`, `dashboard`, CSS y JS).
