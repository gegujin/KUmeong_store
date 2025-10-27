<!-- .github/copilot-instructions.md - guidance for AI coding agents -->

# KUmung_store — Copilot instructions (concise)

Treat this as the quickstart for an AI coding agent that will make code changes in this repository.

- Repo scope: monorepo-like Flutter app (root) + NestJS API under `kumeong-api/`.
- Primary languages: Dart/Flutter (app) and TypeScript (NestJS backend). Focus first on `kumeong-api/src/` for backend changes.

## Big-picture architecture

- Mobile client: Flutter app at repository root (see `pubspec.yaml`). Uses `go_router`, `http`, `web_socket_channel` and JWT-based auth.
- Backend: NestJS app in `kumeong-api/` (see `package.json`). Key modules live under `kumeong-api/src/modules` and `kumeong-api/src/features`.
- Persistence: TypeORM (MySQL) configured via `kumeong-api/src/typeorm.config.ts` (imported in `src/app.module.ts`). Entities are auto-loaded (TypeOrmModule autoLoadEntities: true).
- Mailer: `@nestjs-modules/mailer` configured via `src/core/config/mail.config` and `ConfigModule` driven by `.env` files.
- Middleware: `EnsureUserMiddleware` is applied globally in `AppModule.configure`.

Why this matters for code edits:
- Backend changes should respect NestJS module boundaries (modules under `modules/` and `features/`). Add new providers/controllers to the appropriate module file.
- Database migrations are used (synchronize: false). Do not rely on auto-sync in production; prefer generating migrations and updating TypeORM configs.

## Developer workflows (how to build, run, test)

Root-level (Flutter app) workflows are standard Flutter flows (see `pubspec.yaml`). For backend (NestJS):

- Install dependencies (from `kumeong-api/`):

```powershell
cd "kumeong-api"; npm install
```

- Run in dev/watch mode (hot reload backend):

```powershell
cd "kumeong-api"; npm run start:dev
```

- Build (production):

```powershell
cd "kumeong-api"; npm run build
```

- Tests: unit/e2e via npm scripts in `kumeong-api/package.json` (`npm run test`, `npm run test:e2e`).

Config loading precedence: App uses `ConfigModule.forRoot` with envFilePath order:
`.env.{NODE_ENV}.local`, `.env.{NODE_ENV}`, `.env.local`, `.env`.

Environment variables referenced in `README.md` (JWT, BCRYPT_SALT_ROUNDS, etc.). Keep `.env` secrets out of commits.

## Project-specific conventions & patterns

- NestJS structure follows generator conventions: `modules/*` contain domain modules (Users, Auth, Products). `features/*` contain cross-cutting or feature-grouped modules (chats, friends, university verification).
- Middleware `EnsureUserMiddleware` is applied for all routes — assume req.user or auth behavior is centrally enforced. When adding endpoints, consider middleware order and global application.
- TypeORM: data source is imported from `src/typeorm.config` and `TypeOrmModule.forRoot({ ...(dataSource.options as DataSourceOptions), autoLoadEntities: true, synchronize: false })`. Rely on entities being registered via imports or auto-loading; adding new entities may require updating migration scripts.
- Mailer config is created via `core/config/mail.config` and injected with `ConfigService`. Use ConfigService keys defined in `env.validation`.

Examples (use when making edits):
- To add a new REST controller for products: create `kumeong-api/src/modules/products/controllers/new.controller.ts`, export it in `products.module.ts`, and register any services in `providers`.
- To add a DB entity: place it under `kumeong-api/src/entities/` (or module folder), ensure it's imported by TypeORM or referenced by a module that uses `@InjectRepository`.

## Integration points & external dependencies

- MySQL via `mysql2` and TypeORM. Connection configured in `typeorm.config`.
- SMTP via `@nestjs-modules/mailer` + `nodemailer`; settings come from `ConfigService` and `.env`.
- JWT auth via `@nestjs/jwt` and Passport strategies (see `modules/auth`). Respect token expiration env keys.
- Flutter client communicates over HTTP endpoints described in top-level `README.md` (e.g., `/auth/*`, `/products`, `/chat/*`). Use these canonical paths when adding or modifying API routes.

## Files to check when making changes (quick reference)

- `kumeong-api/src/app.module.ts` — bootstraps modules, middleware, TypeORM, Mailer, and ConfigModule.
- `kumeong-api/package.json` — npm scripts for dev/build/test.
- `kumeong-api/src/typeorm.config.ts` — TypeORM DataSource options and connection details.
- `kumeong-api/src/core/config/env.validation.ts` — environment variable schema (keys expected by app).
- `kumeong-api/src/core/config/mail.config.ts` — mailer factory.
- `kumeong-api/src/modules` and `kumeong-api/src/features` — module boundaries and patterns.

## Safety and non-goals

- Do not commit secrets or `.env` files.
- Avoid large refactors without explicit approval — prefer minimal, well-scoped changes.

## Example PR checklist for AI-generated changes

- Run `npm run lint` in `kumeong-api` and fix lint errors.
- Run unit tests `npm run test` and ensure no regressions.
- Start the backend (`npm run start:dev`) and verify new route loads without runtime errors.
- Update `README.md` or module-level docs when adding public endpoints.

---

If any section is unclear or you'd like more examples (entities, a sample controller, or migration steps), tell me which area to expand and I'll iterate.
