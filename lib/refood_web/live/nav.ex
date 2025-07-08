defmodule RefoodWeb.Nav do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:active_tab, :handle_params, &set_active_tab/3)}
  end

  defp set_active_tab(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do
        {RefoodWeb.ShiftLive, _} -> :shift
        {RefoodWeb.StoragesLive, _} -> :storages
        {RefoodWeb.StoragesLive.NewStorageLive, _} -> :storages
        {RefoodWeb.StorageLive, _} -> :storagesF
        {RefoodWeb.StorageLive.NewItemLive, _} -> :storages
        {RefoodWeb.ProductsLive, _} -> :products
        {RefoodWeb.FamiliesLive, _} -> :families
        {RefoodWeb.HelpQueueLive, _} -> :help_queue
      end

    {:cont, Phoenix.Component.assign(socket, :active_tab, active_tab)}
  end
end
