# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Refood is a Phoenix LiveView application for managing food aid distribution to families. The application tracks families receiving assistance, manages delivery schedules, handles alerts, and provides inventory management capabilities.

## Core Domain: Families

The Families context (`lib/refood/families/`) is the heart of the application.

**Key business logic:**
- Families have scheduled `weekdays` for pickups (e.g., `[:wednesday, :friday]`)
- `list_families_by_date/1` returns families scheduled for a specific date, accounting for swaps and absences
- Alerts are automatically raised when a family has 3+ unwarned absences
- Swaps allow families to temporarily change their pickup day

## Schema Conventions

All schemas use `Refood.Schema` instead of `Ecto.Schema`. It provides UUID primary keys (`:binary_id`), UUID foreign keys, and common imports (Ecto.Changeset, ChangesetHelpers):

```elixir
defmodule Refood.Families.SomeSchema do
  use Refood.Schema  # Instead of: use Ecto.Schema

  schema "table_name" do
    # fields
  end
end
```

## Authorization

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

LiveComponents live in subdirectories named after their parent LiveView (e.g. `families_live/family_details.ex`).

## Development Workflow

1. Create feature branch from `main`
2. Run `mix format` before committing
3. Ensure tests pass with `mix test`
4. Use LiveView for interactive features (preferred over dead views/controllers)
5. Follow Phoenix context pattern - keep business logic in contexts, not LiveViews
