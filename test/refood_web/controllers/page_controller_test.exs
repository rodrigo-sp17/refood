defmodule RefoodWeb.PageControllerTest do
  use RefoodWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/shift"
  end
end
