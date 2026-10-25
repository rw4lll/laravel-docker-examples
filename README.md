# Laravel Docker Examples Project

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
  - [Directory Structure](#directory-structure)
  - [Development Environment](#development-environment)
  - [Production Environment](#production-environment)
- [Getting Started](#getting-started)
  - [Clone the Repository](#clone-the-repository)
  - [Setting Up the Development Environment](#setting-up-the-development-environment)
- [Usage](#usage)
- [Production Environment](#production-environment-1)
  - [Building and Running the Production Environment](#building-and-running-the-production-environment)
- [Technical Details](#technical-details)
- [Contributing](#contributing)
  - [How to Contribute](#how-to-contribute)
- [License](#license)


## Overview

The **Laravel Docker Examples Project** offers practical and modular examples for Laravel developers to create efficient Docker environments for development and production. This project demonstrates modern Docker best practices, including multi-stage builds, modular configurations, and environment-specific customization. It is designed to be educational, flexible, and extendable, providing a solid foundation for Dockerizing Laravel applications.


## Project Structure

The project is organized as a typical Laravel application, with the addition of a `docker` directory containing the Docker configurations and scripts. These are separated by environments and services. There are two main Docker Compose projects in the root directory:

- **compose.dev.yaml**: Orchestrates the development environment.
- **compose.prod.yaml**: Orchestrates the production environment.

### Directory Structure

```
project-root/ 
├── app/ # Laravel app folder
├── ...  # Other Laravel files and directories 
├── docker/ 
│   ├── common/ # Shared configurations
│   ├── development/ # Development-specific configurations 
│   ├── production/ # Production-specific configurations
├── compose.dev.yaml # Docker Compose for development 
├── compose.prod.yaml # Docker Compose for production 
└── .env.example # Example environment configuration
```

This modular structure ensures shared logic between environments while allowing environment-specific customizations.


### Production Environment

The production environment is configured using the `compose.prod.yaml` file. It is optimized for performance and security, using multi-stage builds and runtime-only dependencies. It uses a shared PHP-FPM multi-stage build with the target `production`.

- **Optimized Images**: Multi-stage builds ensure minimal image size and enhanced security.
- **Pre-Built Assets**: Assets are compiled during the build process, ensuring the container is ready to serve content immediately upon deployment.
- **Health Checks**: Built-in health checks monitor service statuses and ensure smooth operation.
- **Security Best Practices**: Minimizes the attack surface by excluding unnecessary packages and users.
- **Docker Compose for Production**: Tailored for deploying Laravel applications with Nginx, PHP-FPM, Redis, and PostgreSQL.
- **Public Disk Ready**: `Storage::disk('public')` works out of the box — the `public/storage` symlink is baked into both images and Nginx mounts only that part of the storage volume, read-only.

This environment is designed for easy deployment to any Docker-compatible hosting platform.


### Development Environment

The development environment is configured using the `compose.dev.yaml` file and builds on the same PHP runtime stage as production. This ensures the development environment is as close to production as possible while still supporting tools like Xdebug and writable permissions.

Key features include:
- **Close Parity with Production**: Mirrors the production environment to minimize deployment issues.
- **Development Tools**: Includes Xdebug for debugging and writable permissions for mounted volumes.
- **Hot Reloading**: Volume mounts enable real-time updates to the codebase without rebuilding containers.
- **Services**: PHP-FPM, Nginx, Redis, PostgreSQL, and Node.js (via NVM).
- **Custom Dockerfiles**: Extends shared configurations to include development-specific tools.

To set up the development environment, follow the steps in the **Getting Started** section.


## Getting Started

Follow these steps to set up and run the Laravel Docker Examples Project:

### Prerequisites
Ensure you have Docker and Docker Compose installed. You can verify by running:

```bash
docker --version
docker compose version
```

If these commands do not return the versions, install Docker and Docker Compose using the official documentation: [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/).

Docker Engine **26.0** or newer is required, because the production stack mounts part of a volume with `subpath`. The setup is tested with Docker Engine 29.7 and Docker Compose 5.4.

### Clone the Repository

```bash
git clone https://github.com/rw4lll/laravel-docker-examples.git
cd laravel-docker-examples
```

### Setting Up the Development Environment

1. Copy the .env.example file to .env and adjust any necessary environment variables:

```bash
cp .env.example .env
```

Hint: adjust the `UID` and `GID` variables in the `.env` file to match your user ID and group ID. You can find these by running `id -u` and `id -g` in the terminal.

2. Start the Docker Compose Services:

```bash
docker compose -f compose.dev.yaml up -d
```

3. Install the dependencies, generate the application key, run the migrations and build the assets. Laravel's `composer setup` script does all of it:

```bash
docker compose -f compose.dev.yaml exec workspace composer setup
```

4. Optionally, start the Vite dev server for hot reloading:

```bash
docker compose -f compose.dev.yaml exec workspace npm run dev
```

Laravel's `composer dev` script is not needed: it starts `php artisan serve` on port 8000, while here Nginx and PHP-FPM already serve the application.

5. Access the Application:

Open your browser and navigate to [http://localhost](http://localhost).

## Usage

Here are some common commands and tips for using the development environment:

### Accessing the Workspace Container

The workspace sidecar container includes Composer, Node.js, NPM, and other tools necessary for Laravel development (e.g. assets building).

```bash
docker compose -f compose.dev.yaml exec workspace bash
```

### Run Artisan Commands:

```bash
docker compose -f compose.dev.yaml exec workspace php artisan migrate
```

### Rebuild Containers:

```bash
docker compose -f compose.dev.yaml up -d --build
```

### Stop Containers:

```bash
docker compose -f compose.dev.yaml down
```

### View Logs:

```bash
docker compose -f compose.dev.yaml logs -f
```

For specific services, you can use:

```bash
docker compose -f compose.dev.yaml logs -f web
```

## Production Environment

The production environment is designed with security and efficiency in mind:

- **Optimized Docker Images**: Uses multi-stage builds to minimize the final image size, reducing the attack surface.
- **Environment Variables Management**: Sensitive data such as passwords and API keys are managed carefully to prevent exposure.
- **User Permissions**: Containers run under non-root users where possible to follow the principle of least privilege.
- **Health Checks**: Implemented to monitor the status of services and ensure they are functioning correctly.
- **HTTPS Setup**: While not included in this example, it's recommended to configure SSL certificates and use HTTPS in a production environment.

### Building and Running the Production Environment

1. Create the `.env` file and give it a real application key and database password:

```bash
cp .env.example .env
echo "APP_KEY=base64:$(openssl rand -base64 32)"   # put this line into .env
```

Set `DB_PASSWORD` before the first start: Postgres applies it only when it creates the database. `APP_ENV` and `APP_DEBUG` can stay as they are, because `compose.prod.yaml` forces `production` and `false`.

2. Build the images and start the stack:

```bash
docker compose -f compose.prod.yaml up -d --build --wait
```

The application is served at [http://localhost](http://localhost). If port 80 is taken, set `NGINX_PORT`; Postgres is published on `127.0.0.1` only, at `POSTGRES_PORT` (default 5432).

### Deploying

The production image can be deployed to any Docker-compatible hosting environment, such as AWS ECS, Kubernetes, or a traditional VPS.

### Upgrading

Releases that change volumes or service versions include tested upgrade steps in their [release notes](https://github.com/rw4lll/laravel-docker-examples/releases).

## Technical Details

- **PHP**: Version **8.5 FPM** is used for optimal performance in both development and production environments.
- **Fonts**: Laravel 13's Vite config self-hosts its web font, downloading it from `fonts.bunny.net` **at build time**. The asset build therefore needs network access to that host; remove the `fonts` entry in `vite.config.js` if you build in an isolated environment.
- **Node.js**: Version **26.x** (LTS) is used for building frontend assets with Vite — via NVM in the `workspace` container, and in the `assets` build stage for production.
- **PostgreSQL**: Version **18** is used as the database in the examples, but you can adjust the configuration to use MySQL if preferred.
- **Redis**: Used for the cache and the queue in both environments. Sessions are stored in the database.
- **Nginx**: Used as the web server to serve the Laravel application and handle HTTP requests.
- **Docker Compose**: Orchestrates the services, simplifying the process of starting and stopping the environment.
- **Health Checks**: Implemented in the Docker Compose configurations and Laravel application to ensure all services are operational.
- **Storage**: Only `storage/app` is persisted in a volume — `storage/framework` is per-build scratch space and logs go to `stderr` (`docker compose logs php-fpm`) rather than to a file inside the container. Mounting the whole `storage/` directory instead would hide the skeleton shipped in the image and break the application with `Please provide a valid cache path.`
- **Public Files**: The `public/storage` symlink that `php artisan storage:link` creates is already there — created at build time for production (in both the PHP and Nginx images) and on every boot by the development entrypoint. It is a *relative* link, so it stays valid on the host as well. Files written to `Storage::disk('public')` are served by Nginx at `/storage/<file>`; the private disk is not mounted into the web container at all.
- **Production Environment Variables**: `compose.prod.yaml` sets `APP_ENV=production` and `APP_DEBUG=false` on `php-fpm`, overriding the development defaults in the shared `.env`, so error pages never expose debug details in production.
- **Demo Routes**: `/health` reports the database, Redis and storage status as JSON. `/info` shows `phpinfo()` and is registered only when `APP_ENV=local`, because it prints every environment variable, secrets included.


### Versioning Policy

Every version is pinned at the level where an update could break something, and left floating below it, so security patches still arrive when the images are rebuilt:

- **Stateful services — major version** (`postgres:18`, `redis:8-alpine`). A major upgrade can change the on-disk data format, so it has to be a deliberate step.
- **Base images — compatibility line** (`php:8.5-fpm-trixie`, `node:26-alpine`, `nginx:1.30-alpine`, `composer/composer:2-bin`). The Debian suffix matters: without it, a new Debian release silently replaces the base image and renames the libraries that `apt-get` installs.
- **Application dependencies — lockfiles** (`composer.lock`, `package-lock.json`), with version ranges in `composer.json` and `package.json`.
- **Code downloaded at build time — exact versions** (the PECL extensions, nvm, and the php-fpm health check script, which is also verified by checksum).

Floating patch versions only arrive on a rebuild, so rebuild with `docker compose build --pull`. Exact pins never update themselves; in a real project, pair them with Renovate or Dependabot.

## Contributing

Contributions are welcome! Whether you find a bug, have an idea for improvement, or want to add a new feature, your input is valuable.

### How to Contribute

1. **Fork the Repository:**

   Click the "Fork" button at the top right of this page to create your own copy of the repository.

2. **Clone Your Fork:**

```bash
    git clone https://github.com/your-user-name/laravel-docker-examples.git
    cd laravel-docker-examples
```

3. Create a Branch:

```bash
    git checkout -b your-feature-branch
```

4. Make Your Changes.

    Implement your changes or additions.

5. Commit Your Changes:

```bash
git commit -m "Description of changes"
```

6. Push to Your Fork:

```bash
    git push origin feature-branch
```

7. Submit a Pull Request:
    - Go to the original repository.
    - Click on "Pull Requests" and then "New Pull Request."
    - Select your fork and branch, and submit your pull request.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
