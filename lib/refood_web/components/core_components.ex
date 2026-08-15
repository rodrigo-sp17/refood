defmodule RefoodWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: RefoodWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  attr :edit, :boolean,
    default: nil,
    doc: "nil hides the edit affordance entirely; false offers it; true means already editing"

  attr :target, :any, default: nil
  attr :size, :atom, default: :lg, values: [:sm, :md, :lg]

  slot :header
  slot :subtitle
  slot :toolbar, doc: "sits under the header and above the scrolling body, e.g. tabs"
  slot :footer, doc: "a bar pinned to the bottom of the dialog, e.g. save/cancel"
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={["w-full p-4 sm:p-6 lg:py-8", modal_size_class(@size)]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class={[
                "shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white shadow-lg ring-1 transition",
                "flex max-h-[calc(100vh-4rem)] flex-col"
              ]}
            >
              <div
                :if={@header != []}
                class="flex shrink-0 flex-row items-start justify-between gap-6 border-b border-zinc-200 px-8 py-5"
              >
                <div class="min-w-0">
                  <h2 id={"#{@id}-title"} class="truncate text-xl font-medium text-zinc-900">
                    {render_slot(@header)}
                  </h2>
                  <p :if={@subtitle != []} class="mt-1 truncate text-sm text-zinc-500">
                    {render_slot(@subtitle)}
                  </p>
                </div>

                <div class="flex shrink-0 flex-row items-center gap-2">
                  <.badge :if={@edit == true} color={:brand}>A editar</.badge>
                  <.link
                    :if={@edit == false}
                    phx-click="edit"
                    phx-target={@target}
                    class="flex flex-row items-center gap-1.5 rounded-lg px-2 py-1.5 text-sm font-semibold text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900"
                  >
                    <.icon name="hero-pencil-square" class="h-4 w-4" /> Editar
                  </.link>
                  <.icon_button
                    phx-click={JS.exec("data-cancel", to: "##{@id}")}
                    icon="hero-x-mark"
                    label={gettext("close")}
                  />
                </div>
              </div>
              <div :if={@header == []} class="absolute top-4 right-4 z-10">
                <.icon_button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  icon="hero-x-mark"
                  label={gettext("close")}
                />
              </div>

              <div :if={@toolbar != []} class="shrink-0 border-b border-zinc-200 px-8">
                {render_slot(@toolbar)}
              </div>

              <div
                id={"#{@id}-content"}
                class={[
                  "min-h-0 flex-1 overflow-y-auto overscroll-contain px-8 py-6",
                  @header == [] && "pt-12"
                ]}
              >
                {render_slot(@inner_block)}
              </div>

              <div
                :if={@footer != []}
                class="shrink-0 border-t border-zinc-200 bg-white px-8 py-4 rounded-b-2xl"
              >
                {render_slot(@footer)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp modal_size_class(:sm), do: "max-w-md"
  defp modal_size_class(:md), do: "max-w-xl"
  defp modal_size_class(:lg), do: "max-w-3xl"

  @doc """
  Renders a confirmation (confirm/deny) modal.
  """
  attr :id, :string, required: true
  attr :question, :string, default: "Do you wish proceed?"
  attr :type, :atom, values: [:normal, :delete], default: :normal
  attr :confirm_text, :string, default: "Yes"
  attr :on_confirm, JS, default: %JS{}
  attr :deny_text, :string, default: "No"
  attr :on_deny, JS, default: %JS{}
  attr :on_cancel, JS, default: %JS{}
  attr :show, :boolean, default: true

  def confirmation_modal(assigns) do
    ~H"""
    <.modal id={@id} show={@show} on_cancel={@on_cancel} size={:md}>
      <div class="flex flex-col gap-10">
        <h2 class="text-2xl text-center">
          {@question}
        </h2>
        <div class="flex justify-center gap-8 h-12">
          <.button
            variant={:ghost}
            pill
            phx-remove={hide_modal(@id)}
            phx-click={JS.exec(@on_deny || @on_cancel, "phx-remove")}
            class="basis-1/3 px-6"
          >
            {@deny_text}
          </.button>
          <.button
            variant={if @type == :delete, do: :danger, else: :primary}
            pill
            phx-remove={hide_modal(@id)}
            phx-click={JS.exec(@on_confirm, "phx-remove")}
            class="basis-1/3 px-6"
          >
            {@confirm_text}
          </.button>
        </div>
      </div>
    </.modal>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"

  attr :autoclose, :boolean,
    default: false,
    doc: "dismisses itself after a few seconds; only for messages that need no action"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook={@autoclose && "AutoDismiss"}
      data-flash-key={@kind}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-emerald-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash id="success-flash" kind={:info} title="Sucesso!" flash={@flash} autoclose />
    <.flash id="error-flash" kind={:error} title="Erro!" flash={@flash} />
    <.flash
      id="client-error"
      kind={:error}
      title="Sem ligação à internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      A tentar ligar de novo <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>

    <.flash
      id="server-error"
      kind={:error}
      title="Algo correu mal"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Aguarde enquanto repomos o serviço
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :danger, :ghost]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :pill, :boolean, default: false, doc: "renders with a fully rounded (pill) shape"
  attr :full_width, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 font-semibold leading-6",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2",
        if(@pill, do: "rounded-3xl", else: "rounded-lg"),
        if(@full_width, do: "block w-full", else: "inline-block"),
        button_size_class(@size),
        button_variant_class(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_size_class(:sm), do: "py-1 px-2.5 text-sm"
  defp button_size_class(:md), do: "py-2 px-3 text-sm"
  defp button_size_class(:lg), do: "py-2.5 px-5 text-base"

  defp button_variant_class(:primary),
    do: "bg-zinc-900 hover:bg-zinc-700 text-white active:text-white/80"

  defp button_variant_class(:secondary),
    do: "bg-zinc-100 hover:bg-zinc-200 text-zinc-900 border border-zinc-300"

  defp button_variant_class(:danger),
    do: "bg-rose-600 hover:bg-rose-700 text-white active:text-white/80"

  defp button_variant_class(:ghost),
    do: "bg-transparent border border-zinc-900 text-zinc-900 hover:bg-zinc-900 hover:text-white"

  @doc """
  Renders an on/off switch.

  Use for a setting that takes effect immediately - not as a form input. The
  label is part of the control, so the whole thing is one hit target.

  ## Examples

      <.switch checked={@tv?} label="Modo TV" phx-click="toggle-display-mode" />
  """
  attr :checked, :boolean, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  def switch(assigns) do
    ~H"""
    <button
      type="button"
      role="switch"
      aria-checked={to_string(@checked)}
      class={[
        "group flex items-center gap-2 rounded-3xl py-1 px-2 text-sm font-semibold leading-6",
        "text-zinc-600 hover:text-zinc-900",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2",
        @class
      ]}
      {@rest}
    >
      {@label}
      <span class={[
        "relative h-6 w-11 shrink-0 rounded-3xl border motion-safe:transition-colors",
        if(@checked,
          do: "bg-brand border-brand",
          else: "bg-zinc-200 border-zinc-300 group-hover:bg-zinc-300"
        )
      ]}>
        <span class={[
          "absolute top-0.5 h-4 w-4 rounded-full bg-white shadow-sm motion-safe:transition-all",
          if(@checked, do: "left-6", else: "left-0.5")
        ]} />
      </span>
    </button>
    """
  end

  @doc """
  Renders a status pill.

  ## Examples

      <.badge color={:success}>Troca</.badge>
      <.badge color={:danger}>Faltou</.badge>
  """
  attr :color, :atom,
    default: :neutral,
    values: [:success, :warning, :danger, :info, :neutral, :brand]

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <div class={[
      "px-2.5 py-1 border rounded-3xl text-center text-sm font-bold whitespace-nowrap shrink-0",
      badge_color_class(@color),
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp badge_color_class(:success), do: "border-emerald-600 text-emerald-600"
  defp badge_color_class(:warning), do: "border-amber-500 text-amber-600"
  defp badge_color_class(:danger), do: "border-rose-600 text-rose-600"
  defp badge_color_class(:info), do: "border-blue-600 text-blue-600"
  defp badge_color_class(:neutral), do: "border-zinc-400 text-zinc-600"

  # Filled rather than outlined: this one marks a live state, not a category.
  defp badge_color_class(:brand), do: "border-brand bg-brand text-zinc-900"

  @doc """
  An icon-only button. The label is required — it is the only name the control has.

  ## Examples

      <.icon_button icon="hero-x-mark" label="Fechar" phx-click={hide_modal("x")} />
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value type)

  def icon_button(assigns) do
    ~H"""
    <button
      type="button"
      aria-label={@label}
      title={@label}
      class={[
        "rounded-lg p-1.5 text-zinc-500 hover:bg-zinc-100 hover:text-zinc-900",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900",
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class="h-5 w-5" />
    </button>
    """
  end

  @doc """
  Returns a button triggered dropdown with aria keyboard and focus supporrt.

  Accepts the follow slots:

    * `:id` - The id to uniquely identify this dropdown
    * `:trigger` - optional custom trigger content; defaults to a kebab-menu
      icon link. When provided, the caller's element is responsible for its
      own `phx-click`, targeting `show_dropdown/1` on the `"-dropdown"`
      suffixed id.

  ## Examples

      <.dropdown id={@id}>
        <:link navigate={profile_path(@current_user)}>View Profile</:link>
        <:link navigate={~p"/profile/settings"}Settings</:link>
      </.dropdown>
  """
  attr :id, :string, required: true

  attr :position, :atom,
    default: :top_right,
    values: [:top_right, :bottom_left_fixed, :below],
    doc: "where the panel opens relative to its trigger"

  slot :trigger

  slot :link do
    attr :navigate, :string
    attr :href, :string
    attr :patch, :string
    attr :method, :any
    attr :on_click, :any
  end

  def dropdown(assigns) do
    ~H"""
    <.link
      :if={@trigger == []}
      id={@id}
      phx-click={show_dropdown("##{@id}-dropdown")}
      aria-haspopup="true"
    >
      <.icon name="hero-ellipsis-vertical" class="h-6 w-6" />
    </.link>
    {render_slot(@trigger)}
    <div
      id={"#{@id}-dropdown"}
      phx-click-away={hide_dropdown("##{@id}-dropdown")}
      class={[
        "hidden mx-3 z-10 mt-1 rounded-md shadow-lg bg-white ring-1 ring-zinc-900/5 divide-y divide-zinc-200",
        dropdown_position_class(@position)
      ]}
      role="menu"
      aria-labelledby={@id}
    >
      <div class="py-1">
        <%= for link <- @link do %>
          <.link
            tabindex="-1"
            role="menuitem"
            class="block truncate px-4 py-2 text-sm text-zinc-700 hover:bg-zinc-100 focus:outline-hidden focus:ring-2 focus:ring-zinc-900 focus:ring-offset-2 focus:ring-offset-zinc-100"
            phx-remove={hide_dropdown("##{@id}-dropdown")}
            phx-click={Map.get(link, :on_click, nil)}
            patch={Map.get(link, :patch, nil)}
            {link}
          >
            {render_slot(link)}
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp dropdown_position_class(:top_right), do: "absolute right-0 origin-top-right"

  defp dropdown_position_class(:bottom_left_fixed),
    do: "fixed bottom-4 left-15 origin-bottom-left z-50"

  defp dropdown_position_class(:below), do: ""

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-3xl font-semibold leading-8 text-zinc-800">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :id, :string
    attr :label, :string
    attr :sort, :atom
    attr :on_sort, :any, doc: "the function for handling a phx-click on the table column"
  end

  slot :action, doc: "the slot for showing user actions in the last table column"
  slot :top_controls, doc: "the slot for showing controls on top of table"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto mt-11 px-0 bg-white rounded-xl">
      {render_slot(@top_controls)}
      <table class="w-[40rem] sm:w-full bg-white">
        <thead class="border-y border-zinc-200 text-base text-left text-zinc-500 leading-6">
          <tr>
            <th :for={col <- @col} class="py-4 pl-4 w-6 font-semibold hover:bg-zinc-50">
              <div
                class="flex items-center gap-1"
                phx-click={col[:on_sort] && col[:on_sort].(next_sort(col[:sort]))}
              >
                {col[:label]}
                <.icon :if={col[:sort] == :asc} name="hero-chevron-up" />
                <.icon :if={col[:sort] == :desc} name="hero-chevron-down" />
              </div>
            </th>
            <th class="relative p-0 pb-4"><span class="sr-only">{gettext("Actions")}</span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-base leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative pr-8 px-4 whitespace-nowrap", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "text-zinc-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 px-6">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp next_sort(nil), do: :asc
  defp next_sort(:asc), do: :desc
  defp next_sort(:desc), do: nil

  @doc ~S"""
  Renders a table search input.
  """

  attr :value, :string, required: true
  attr :on_change, :string, required: true
  attr :on_reset, :string, required: true

  def table_search_input(assigns) do
    ~H"""
    <div class="relative w-fit rounded-lg border border-zinc-300 focus-within:border-zinc-400">
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center">
        <.icon name="hero-magnifying-glass" class="h-5 w-5" />
      </div>
      <input
        id="table-search-input"
        value={@value}
        phx-keyup={@on_change}
        type="text"
        class="h-10 pl-10 pr-3 rounded-lg text-zinc-800 placeholder-zinc-400 text-xl focus:outline-none"
        placeholder="Filtrar"
        role="combobox"
        aria-expanded="false"
        aria-controls="options"
      />
      <div
        :if={@value !== ""}
        class="absolute inset-y-0 right-0 pr-3 flex items-center"
        phx-click={@on_reset}
      >
        <.icon name="hero-x-mark" class="h-5 w-5 hover:bg-zinc-700" />
      </div>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-500">{item.title}</dt>
          <dd class="text-zinc-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_dropdown(to) do
    JS.show(
      to: to,
      transition:
        {"transition ease-out duration-120", "transform opacity-0 scale-95",
         "transform opacity-100 scale-100"}
    )
    |> JS.set_attribute({"aria-expanded", "true"}, to: to)
  end

  def hide_dropdown(to) do
    JS.hide(
      to: to,
      transition:
        {"transition ease-in duration-120", "transform opacity-100 scale-100",
         "transform opacity-0 scale-95"}
    )
    |> JS.remove_attribute("aria-expanded", to: to)
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    # Must be shown as flex, not the JS.show default of block: the dialog is a
    # flex column so that only its body scrolls and the footer stays pinned.
    |> JS.show(
      to: "##{id}-container",
      display: "flex",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  def expand_sidebar(js \\ %JS{}) do
    js
    |> JS.show(to: "#navbar", transition: "fade-in")
    |> JS.show(
      to: "#navbar",
      display: "flex",
      time: 300,
      transition:
        {"transition ease-in-out duration-300 transform", "-translate-x-full", "translate-x-0"}
    )
    |> JS.hide(to: "#navbar-minimal")
  end

  def retract_sidebar(js \\ %JS{}) do
    js
    |> JS.hide(to: "#navbar", transition: "fade-out")
    |> JS.hide(
      to: "#navbar",
      time: 300,
      transition:
        {"transition ease-in-out duration-300 transform", "translate-x-0", "-translate-x-full"}
    )
    |> JS.show(to: "#navbar-minimal", display: "flex", transition: "fade-in")
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(RefoodWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(RefoodWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
