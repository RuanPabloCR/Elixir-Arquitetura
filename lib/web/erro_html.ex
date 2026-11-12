defmodule PedidosWeb.ErroHTML do
  @moduledoc "Paginas de erro minimas (404, 500): so o texto do status."

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
