# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Refood is a Phoenix LiveView application for managing food aid distribution to families. The application tracks families receiving assistance, manages delivery schedules, handles alerts, and provides inventory management capabilities.

**Tech Stack:**
- Elixir ~> 1.18 with Phoenix ~> 1.7.6
- Phoenix LiveView for interactive UI
- PostgreSQL database with Ecto
- TailwindCSS for styling
- Docker for deployment

## Common Commands

### Development Setup
```bash
# Initial setup (install deps, create DB, migrate, seed, build assets)
mix setup

# Start development server (runs on http://localhost:4000)
mix phx.server

# Start server with IEx console
iex -S mix phx.server
```

### Database Operations
```bash
# Create and migrate database
mix ecto.setup

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Create a new migration
mix ecto.gen.migration migration_name

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback
```

### Testing
```bash
# Run all tests (automatically creates and migrates test DB)
mix test

# Run a single test file
mix test test/path/to/test_file.exs

# Run a specific test by line number
mix test test/path/to/test_file.exs:42

# Run tests with coverage
mix test --cover
```

### Assets
```bash
# Install asset dependencies
mix assets.setup

# Build assets for development
mix assets.build

# Build minified assets for production
mix assets.deploy
```

### Code Quality
```bash
# Format code according to .formatter.exs
mix format

# Check if code is formatted
mix format --check-formatted
```

## Architecture

### Directory Structure

The codebase follows Phoenix conventions with a clear separation between domain logic and web interface:

- **`lib/refood/`** - Domain/business logic layer (contexts)
  - `accounts.ex` - User authentication and management
  - `families/` - Family management domain (main feature)
  - `inventory/` - Inventory tracking for food supplies

- **`lib/refood_web/`** - Web interface layer
  - `live/` - Phoenix LiveView modules for interactive pages
  - `controllers/` - Traditional Phoenix controllers
  - `components/` - Reusable UI components

- **`priv/repo/migrations/`** - Database migrations
- **`test/`** - Test files mirroring `lib/` structure
- **`assets/`** - Frontend assets (CSS, JS)

### Core Domain: Families

The Families context (`lib/refood/families/`) is the heart of the application:

**Resources (schemas in `lib/refood/families/resources/`):**
- `Family` - Represents families receiving aid with status (`:active`, `:paused`, `:finished`, `:queued`)
- `Address` - Family address information
- `Absence` - Tracks when families miss scheduled pickups
- `Alert` - System alerts for families (e.g., excessive absences)
- `Swap` - Manages schedule changes (swapping pickup dates)

**Context functions (`lib/refood/families/families.ex`):**
- Family lifecycle: `create_family/1`, `reactivate_family/2`, `deactivate_family/1`
- Querying: `list_families/1`, `list_families_by_date/1`, `get_family!/1`
- Absence tracking: `add_absence/1`, `update_absence/2`, `delete_absence/1`
- Schedule swaps: `add_swap/2`
- Alert management: `raise_alert/2`, `dismiss_alerts/3`
- Contact registration: `register_contact/2`

**Key business logic:**
- Families have scheduled `weekdays` for pickups (e.g., `[:wednesday, :friday]`)
- `list_families_by_date/1` returns families scheduled for a specific date, accounting for swaps and absences
- Alerts are automatically raised when a family has 3+ unwarned absences
- Swaps allow families to temporarily change their pickup day

### Schema Conventions

All schemas use `Refood.Schema` which provides:
- UUID primary keys (`:binary_id`)
- UUID foreign keys
- Common imports (Ecto.Changeset, ChangesetHelpers)

Example:
```elixir
defmodule Refood.Families.SomeSchema do
  use Refood.Schema  # Instead of: use Ecto.Schema

  schema "table_name" do
    # fields
  end
end
```

### Changeset Helpers

`Refood.ChangesetHelpers` provides utilities for array fields:
- `trim_array/3` - Remove blank values
- `validate_array/3` - Validate array elements against allowed values
- `sort_array/2` - Sort array values
- `clean_and_validate_array/4` - Combined cleanup and validation
- `sanitize_array/3` - Clean arrays in raw attribute maps

### LiveView Architecture

**Main LiveViews:**
- `FamiliesLive` - Manage all families (list, create, edit)
- `ShiftLive` - Daily shift view showing scheduled families for a date
- `HelpQueueLive` - Manage queue of families waiting for aid
- `UsersLive` - User management (admin only)

**LiveView Conventions:**
- All LiveViews use `use RefoodWeb, :live_view` which includes:
  - Authorization helpers via `RefoodWeb.Authorization`
  - Custom container styling for consistent layout
  - Flash message handling via `handle_info/2`
- LiveComponents are in subdirectories (e.g., `families_live/family_details.ex`)
- Authorization uses `authorize(socket, roles)` pattern with role checks

**Authorization:**
User roles: `:admin`, `:manager`, `:volunteer`
- Admins have full access
- Managers can manage families and users
- Volunteers have read-only access to shifts

Check authorization in LiveView event handlers:
```elixir
def handle_event("protected_action", params, socket) do
  with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
    # perform action
  end
end
```

### RefoodWeb Module Structure

The `RefoodWeb` module (`lib/refood_web.ex`) defines reusable macros via `__using__/1`:
- `:controller` - Traditional Phoenix controllers
- `:live_view` - Phoenix LiveView modules
- `:live_component` - Phoenix LiveComponent modules
- `:html` - Phoenix.Component modules
- `:router` - Router configuration

This provides consistent imports and behavior across the web layer.

### Testing

**Test Support:**
- Use ExMachina factories (`test/support/factory.ex`) for test data
- Factories available: `user`, `family`, `absence`, `swap`, `alert`, `address`, `product`, `storage`, `item`
- `DataCase` for database tests
- `ConnCase` for controller/integration tests

**Example:**
```elixir
test "creates a family" do
  attrs = params_for(:family, name: "Silva Family")
  assert {:ok, family} = Families.create_family(attrs)
end
```

## Database Notes

- Uses PostgreSQL with UUID primary keys
- Migrations in `priv/repo/migrations/`
- Seeds in `priv/repo/seeds.exs`
- Test database is created/migrated automatically via `test` mix alias

## Development Workflow

1. Create feature branch from `main` (current working branch: `loan-feature`)
2. Run `mix format` before committing
3. Ensure tests pass with `mix test`
4. Use LiveView for interactive features (preferred over dead views/controllers)
5. Follow Phoenix context pattern - keep business logic in contexts, not LiveViews

## Deployment

- Dockerized application (see `Dockerfile`)
- Configured for Fly.io deployment (see `fly.toml`)
- Production config in `config/runtime.exs`
- Release configuration in `rel/`
