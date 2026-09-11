defmodule RefoodWeb.FormComponents do
  @moduledoc """
  The form system — "a ficha".

  Records in this app are read far more often than they are edited, and the
  thing they replace is a paper card in a box. So a record renders as a card:
  a fixed label gutter on the left, values on the right, sections stacked down
  the page.

  The gutter is the point. Reading and editing use the same geometry — only the
  contents of the value column change — so toggling "Editar" never moves
  anything on screen. Read mode renders real text with an em dash for blanks,
  not disabled inputs.

  Mode is threaded once, by `record_form/1`, and yielded to each `field/1`:

      <.record_form :let={rf} for={@form} mode={@mode} phx-submit="save">
        <.section title="Identificação">
          <.field rf={rf} name={:name} label="Nome" />
          <.field rf={rf} name={:adults} label="Adultos" type="number" width={:xs} />
        </.section>
      </.record_form>

  Forms that only ever create something pass `mode={:edit}`.
  """
  use Phoenix.Component
  use Gettext, backend: RefoodWeb.Gettext

  import RefoodWeb.CoreComponents, only: [button: 1, icon: 1, translate_error: 1]

  alias Phoenix.LiveView.JS
  alias Refood.Format

  # Every control shares one line box: 24px of leading plus 7px of padding above
  # and below plus a 1px border. Labels and read-mode values pad to match, which
  # is what keeps read and edit modes exactly the same height.
  defp control_class(errors) do
    [
      "block w-full rounded-lg border px-3 py-[7px] text-sm leading-6 text-zinc-900",
      "placeholder-zinc-400 focus:outline-none",
      if(errors == [],
        do: "border-zinc-300 focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900",
        else: "border-rose-400 focus:border-rose-600 focus:ring-1 focus:ring-rose-600"
      )
    ]
  end

  @doc """
  Wraps a record's fields, threading the read/edit mode to each one.

  Yields `%{form: form, mode: mode}` — pass it straight to `field/1` as `rf`.

  In edit mode a gold rule runs down the left edge of the whole body. The rule
  is always present and merely transparent when reading, so entering edit mode
  costs no layout.
  """
  attr :for, :any, required: true, doc: "a form built with `to_form/2`"
  attr :mode, :atom, default: :edit, values: [:read, :edit]
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart)

  slot :inner_block, required: true

  def record_form(assigns) do
    # Yield the form that was passed in rather than the one `<.form>` yields:
    # `Phoenix.Component.form/1` always forwards `:as`, and a nil `:as` blanks
    # the form's name, which breaks `inputs_for` on nested records. Using the
    # original is also what LiveView recommends for change tracking.
    assigns =
      assign_new(assigns, :form, fn ->
        if is_struct(assigns.for, Phoenix.HTML.Form), do: assigns.for, else: to_form(assigns.for)
      end)

    ~H"""
    <.form for={@form} {@rest}>
      <div class={[
        "border-l-2 pl-6 motion-safe:transition-colors",
        if(@mode == :edit, do: "border-brand", else: "border-transparent"),
        @class
      ]}>
        <.error_summary :if={@mode == :edit} form={@form} />
        <div class="flex flex-col gap-10">
          {render_slot(@inner_block, %{form: @form, mode: @mode})}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  A titled group of fields. Owns its own spacing — callers never pad sections.
  """
  attr :title, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section class={@class}>
      <h3 class="mb-5 border-b border-zinc-200 pb-2 text-xs font-semibold uppercase tracking-widest text-zinc-500">
        {@title}
      </h3>
      <div class="flex flex-col gap-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc """
  One row of the ficha: label in the gutter, value beside it.

  Renders text when `rf.mode` is `:read` and an input when it is `:edit`, in the
  same vertical space either way.

  `width` caps the value column so a number field is not 600px wide; it does not
  affect the gutter. Pass `form` to render a field of a nested `inputs_for`
  form while keeping the surrounding mode.
  """
  attr :rf, :map, required: true, doc: "the {form, mode} pair yielded by record_form/1"
  attr :name, :atom, required: true
  attr :label, :string, required: true

  attr :type, :string,
    default: "text",
    values: ~w(text number email tel password url search date datetime-local time
               textarea select checkbox checkgroup weekdays)

  attr :form, :any, default: nil, doc: "override form, e.g. a nested inputs_for form"
  attr :hint, :string, default: nil, doc: "guidance shown under the control while editing"
  attr :readonly, :boolean, default: false, doc: "always renders as text, even while editing"

  attr :required, :boolean,
    default: false,
    doc: """
    Marks the field as required in the label. Deliberately does not set the HTML
    `required` attribute: the browser would block submission and show its own
    bubble, in its own locale, bypassing the error summary. The changeset is the
    single source of truth for what is required.
    """

  attr :width, :atom, default: :full, values: [:xs, :sm, :md, :lg, :full]
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :multiple, :boolean, default: false

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols list max maxlength min minlength
                pattern placeholder readonly rows size step)

  def field(assigns) do
    form = assigns.form || assigns.rf.form
    field = form[assigns.name]
    errors = field_errors(field)

    assigns =
      assigns
      |> assign(:mode, if(assigns.readonly, do: :read, else: assigns.rf.mode))
      |> assign(:field, field)
      |> assign(:errors, Enum.map(errors, &translate_error/1))

    ~H"""
    <div class="md:grid md:grid-cols-12 md:gap-4">
      <label
        :if={@mode == :edit}
        for={@field.id}
        class="block py-[7px] text-xs font-semibold uppercase leading-6 tracking-wide text-zinc-500 md:col-span-3"
      >
        {@label}<span :if={@required} class="text-rose-600" aria-hidden="true">&nbsp;*</span>
        <span :if={@required} class="sr-only">(obrigatório)</span>
      </label>
      <span
        :if={@mode == :read}
        id={"#{@field.id}-label"}
        class="block py-[7px] text-xs font-semibold uppercase leading-6 tracking-wide text-zinc-500 md:col-span-3"
      >
        {@label}
      </span>

      <div class="md:col-span-9">
        <div class={width_class(@width)}>
          <.read_value
            :if={@mode == :read}
            type={@type}
            value={@field.value}
            options={@options}
            labelled_by={"#{@field.id}-label"}
          />
          <.input
            :if={@mode == :edit}
            field={@field}
            type={@type}
            errors={@errors}
            options={@options}
            prompt={@prompt}
            multiple={@multiple}
            describedby={@hint && "#{@field.id}-hint"}
            {@rest}
          />
        </div>
        <p :if={@hint && @mode == :edit} id={"#{@field.id}-hint"} class="mt-1.5 text-xs text-zinc-500">
          {@hint}
        </p>
        <.error :for={msg <- @errors} :if={@mode == :edit} id={"#{@field.id}-error"}>{msg}</.error>
      </div>
    </div>
    """
  end

  # Changeset-backed fields stay quiet until the user has touched them. Forms
  # built from a plain map carry errors the caller set deliberately, so those
  # always show.
  defp field_errors(%Phoenix.HTML.FormField{form: %{source: %Ecto.Changeset{}}} = field) do
    if Phoenix.Component.used_input?(field), do: field.errors, else: []
  end

  defp field_errors(field), do: field.errors

  defp width_class(:xs), do: "max-w-24"
  defp width_class(:sm), do: "max-w-44"
  defp width_class(:md), do: "max-w-xs"
  defp width_class(:lg), do: "max-w-md"
  defp width_class(:full), do: "w-full"

  # Read mode. Values are text, blanks are an em dash — never a disabled input.
  attr :type, :string, required: true
  attr :value, :any, required: true
  attr :options, :list, default: []
  attr :labelled_by, :string, default: nil

  defp read_value(%{type: "weekdays"} = assigns) do
    assigns = assign(assigns, :selected, Enum.map(List.wrap(assigns.value), &to_string/1))

    ~H"""
    <div class="flex flex-wrap gap-1.5 py-[7px]" aria-labelledby={@labelled_by}>
      <span
        :for={{label, value} <- Format.weekday_options()}
        class={[
          "rounded-lg border px-2.5 py-0.5 text-sm font-semibold leading-6",
          if(to_string(value) in @selected,
            do: "border-brand bg-brand text-zinc-900",
            else: "border-zinc-200 text-zinc-400"
          )
        ]}
      >
        {label}
      </span>
    </div>
    """
  end

  defp read_value(%{type: "checkbox"} = assigns) do
    assigns = assign(assigns, :text, if(assigns.value in [true, "true"], do: "Sim", else: "Não"))
    ~H"<.plain_value text={@text} labelled_by={@labelled_by} />"
  end

  defp read_value(%{type: "select"} = assigns) do
    label =
      Enum.find_value(assigns.options, fn
        {label, value} -> to_string(value) == to_string(assigns.value) && label
        value -> to_string(value) == to_string(assigns.value) && value
      end)

    assigns = assign(assigns, :text, label)
    ~H"<.plain_value text={@text} labelled_by={@labelled_by} />"
  end

  defp read_value(%{type: "date"} = assigns) do
    assigns = assign(assigns, :text, format_temporal(assigns.value, &Format.date/1))
    ~H"<.plain_value text={@text} labelled_by={@labelled_by} />"
  end

  defp read_value(%{type: type} = assigns) when type in ["datetime-local", "time"] do
    assigns = assign(assigns, :text, format_temporal(assigns.value, &Format.datetime/1))
    ~H"<.plain_value text={@text} labelled_by={@labelled_by} />"
  end

  defp read_value(%{type: "textarea"} = assigns) do
    ~H"""
    <p
      :if={not blank?(@value)}
      class="whitespace-pre-line py-[7px] text-[15px] leading-6 text-zinc-900"
      aria-labelledby={@labelled_by}
    >
      {@value}
    </p>
    <.plain_value :if={blank?(@value)} text={nil} labelled_by={@labelled_by} />
    """
  end

  defp read_value(assigns) do
    ~H"<.plain_value text={@value} labelled_by={@labelled_by} />"
  end

  attr :text, :any, required: true
  attr :labelled_by, :string, default: nil

  defp plain_value(assigns) do
    ~H"""
    <p class="py-[7px] text-[15px] leading-6 text-zinc-900" aria-labelledby={@labelled_by}>
      <span :if={blank?(@text)} class="text-zinc-400" aria-label="sem registo">—</span>
      <span :if={not blank?(@text)}>{@text}</span>
    </p>
    """
  end

  defp format_temporal(value, formatter) when is_struct(value), do: formatter.(value)
  defp format_temporal(value, _formatter), do: value

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?([]), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false

  @doc """
  Announces that a submit failed, so the form does not appear to do nothing.

  It states the count and defers to the inline errors for the detail — they
  already name the field — and moves focus to the first control at fault.
  """
  attr :form, :any, required: true

  def error_summary(assigns) do
    errors = submitted_errors(assigns.form)

    assigns =
      assigns
      |> assign(:count, length(errors))
      |> assign(:show?, errors != [])

    ~H"""
    <div
      :if={@show?}
      id={"#{@form.id}-error-summary"}
      role="alert"
      tabindex="-1"
      phx-mounted={JS.focus(to: "[aria-invalid='true']")}
      class="mb-8 flex gap-2 rounded-lg border border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-900"
    >
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <p>
        <span class="font-semibold">Não foi possível guardar.</span>
        {if @count == 1,
          do: "Corrija o campo assinalado abaixo.",
          else: "Corrija os #{@count} campos assinalados abaixo."}
      </p>
    </div>
    """
  end

  # Errors only count once a submit has been attempted — a changeset with no
  # action is still being filled in.
  defp submitted_errors(%{source: %Ecto.Changeset{action: action}} = form)
       when action not in [nil, :validate],
       do: form.errors

  defp submitted_errors(_form), do: []

  @doc """
  Renders an input with its error messages.

  Prefer `field/1`, which places this in the ficha gutter and handles read mode.
  Reach for `input/1` directly only where there is no label gutter to sit in —
  hidden fields, search boxes, standalone checkboxes.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week checkgroup weekdays)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, default: []
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :describedby, :string, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors =
      case assigns do
        %{errors: [_ | _] = errors} -> errors
        _ -> field_errors(field)
      end

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &maybe_translate/1))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label class="flex items-center gap-3 py-[7px] text-sm leading-6 text-zinc-700">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          aria-invalid={@errors != [] && "true"}
          class="h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-2 focus:ring-zinc-900 focus:ring-offset-2"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "weekdays"} = assigns) do
    assigns = assign(assigns, :selected, Enum.map(List.wrap(assigns.value), &to_string/1))

    ~H"""
    <div>
      <fieldset class="flex flex-wrap gap-1.5 py-[7px]" aria-invalid={@errors != [] && "true"}>
        <input type="hidden" name={@name} value="" />
        <label :for={{label, value} <- Format.weekday_options()} class="cursor-pointer">
          <input
            type="checkbox"
            name={@name}
            value={value}
            checked={to_string(value) in @selected}
            class="peer sr-only"
            {@rest}
          />
          <span class={[
            "block select-none rounded-lg border px-2.5 py-0.5 text-sm font-semibold leading-6",
            "peer-focus-visible:ring-2 peer-focus-visible:ring-zinc-900 peer-focus-visible:ring-offset-2",
            if(to_string(value) in @selected,
              do: "border-brand bg-brand text-zinc-900",
              else: "border-zinc-300 text-zinc-600 hover:border-zinc-400 hover:bg-zinc-50"
            )
          ]}>
            {label}
          </span>
        </label>
      </fieldset>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "checkgroup"} = assigns) do
    assigns = assign(assigns, :selected, Enum.map(List.wrap(assigns.value), &to_string/1))

    ~H"""
    <div>
      <fieldset
        class={[
          "rounded-lg border",
          if(@errors == [], do: "border-zinc-300", else: "border-rose-400")
        ]}
        aria-invalid={@errors != [] && "true"}
      >
        <div class="grid grid-cols-1 gap-2 p-3 sm:grid-cols-2">
          <input type="hidden" name={@name} value="" />
          <label
            :for={{label, value} <- @options}
            class="flex items-center gap-2 text-sm leading-6 text-zinc-700"
            for={"#{@name}-#{value}"}
          >
            <input
              type="checkbox"
              id={"#{@name}-#{value}"}
              name={@name}
              value={value}
              checked={to_string(value) in @selected}
              class="h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-2 focus:ring-zinc-900 focus:ring-offset-2"
              {@rest}
            />
            {label}
          </label>
        </div>
      </fieldset>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={describedby(@id, @errors, @describedby)}
        class={[control_class(@errors), "bg-white"]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={describedby(@id, @errors, @describedby)}
        class={[control_class(@errors), "min-h-24"]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" name={@name} id={@id} value={@value} {@rest} />
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={describedby(@id, @errors, @describedby)}
        class={control_class(@errors)}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp describedby(id, errors, hint_id) do
    [hint_id, errors != [] && "#{id}-error"]
    |> Enum.filter(&is_binary/1)
    |> case do
      [] -> nil
      ids -> Enum.join(ids, " ")
    end
  end

  defp maybe_translate({_msg, _opts} = error), do: translate_error(error)
  defp maybe_translate(message) when is_binary(message), do: message

  @doc """
  A field label. Used by `input/1` when it is called outside the ficha gutter.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label
      for={@for}
      class="mb-1 block text-xs font-semibold uppercase leading-6 tracking-wide text-zinc-500"
    >
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  An inline error message, shown beneath the control it belongs to.
  """
  attr :id, :string, default: nil
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p id={@id} class="mt-1.5 flex gap-1.5 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  The footer bar for an editable record: what is unsaved, and what to do about it.

  Save stays disabled until something actually changes, so the bar always tells
  the truth about the state of the record.
  """
  attr :form, :any, required: true
  attr :submit_form, :string, required: true, doc: "id of the form element this submits"
  attr :target, :any, default: nil
  attr :submit_label, :string, default: "Guardar alterações"
  attr :cancel_event, :string, default: "cancel-edit"

  def form_actions(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4">
      <p class="text-sm text-zinc-500">{change_summary(@form)}</p>
      <div class="flex gap-3">
        <.button type="button" variant={:ghost} phx-click={@cancel_event} phx-target={@target}>
          Cancelar
        </.button>
        <.button type="submit" form={@submit_form} disabled={not dirty?(@form)}>
          {@submit_label}
        </.button>
      </div>
    </div>
    """
  end

  @doc """
  Whether the form holds changes that have not been saved.
  """
  def dirty?(%{source: %Ecto.Changeset{} = changeset}), do: change_count(changeset) > 0
  def dirty?(_form), do: false

  @doc """
  How many individual fields have been changed, counting nested records.
  """
  def change_count(%Ecto.Changeset{changes: changes}) do
    Enum.reduce(changes, 0, fn
      {_field, %Ecto.Changeset{} = nested}, acc -> acc + change_count(nested)
      {_field, _value}, acc -> acc + 1
    end)
  end

  defp change_summary(%{source: %Ecto.Changeset{} = changeset}) do
    case change_count(changeset) do
      0 -> "Sem alterações"
      1 -> "1 alteração por guardar"
      count -> "#{count} alterações por guardar"
    end
  end

  defp change_summary(_form), do: "Sem alterações"

  @doc """
  A list of records attached to the thing being viewed — loans, absences, swaps.

  These are not form fields: their actions commit immediately. Keeping them in
  their own component keeps them out of the form, where staged-until-save is the
  rule.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :items, :list, required: true
  attr :empty_message, :string, default: "Sem registos"

  slot :action, doc: "an action for the list as a whole, e.g. adding an entry"
  slot :item, required: true

  def record_list(assigns) do
    ~H"""
    <section>
      <div class="mb-2 flex items-center justify-between gap-4">
        <h3 class="text-xs font-semibold uppercase tracking-widest text-zinc-500">{@title}</h3>
        {render_slot(@action)}
      </div>
      <div id={@id} class="overflow-hidden rounded-lg border border-zinc-200">
        <p :if={@items == []} class="px-3 py-4 text-center text-sm text-zinc-500">
          {@empty_message}
        </p>
        <div
          :for={item <- @items}
          class="flex items-center justify-between gap-4 border-b border-zinc-100 px-3 py-2.5 text-sm last:border-b-0"
        >
          {render_slot(@item, item)}
        </div>
      </div>
    </section>
    """
  end
end
