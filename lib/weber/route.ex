defmodule Weber.Route do

  @moduledoc """
    This module handles routing of weber web application.
    Use 'route' macros for declaring routing.

      ## Example

        route on("ANY", '/', Controller1, Action1)
           |> on ("GET", '/user/:name', Controller2, Action2)
           |> on ("POST", "/user/add/:username", "Controller2#Action2")
           |> on ("GET", '/user/:name/delete', Controller2, Action1)
  """

  import String

  import Weber.Utils
  import Weber.Http.Url

  defmacro route(routeList) do
    quote do
      def unquote(:__route__)() do
        unquote(routeList)
      end
    end
  end

  def link(controller, action, bindings // []) do
    routes_with_same_controller = Enum.filter(Route.__route__,
      fn(route) ->
        :lists.member({:controller, controller}, route)
      end)
    routes_with_same_action = Enum.filter(routes_with_same_controller,
      fn(route) ->
        :lists.member({:action, action}, route)
      end) |> Enum.at(0)
    parsed_route = getBinding(Keyword.get(routes_with_same_action, :path))
    List.foldl(parsed_route, "",
      fn({type, value}, acc) ->
        case type do
          :segment -> acc <> "/" <> value
          :binding -> acc <> "/" <> to_bin(Keyword.get(bindings, binary_to_atom(value)))
        end
      end)
  end

  @doc """
    Create list with router path.

    controllerAndAction - is controller and action in: :Controller#action format
  """
  def on(method, path, controllerAndAction) when is_binary(controllerAndAction) do
    [controller, action] = split(controllerAndAction, "#")
    [[method: method, path: path, controller: binary_to_atom(controller), action: binary_to_atom(action)]]
  end

  def on(routesList, method, path, controllerAndAction) when is_binary(controllerAndAction) do
    [controller, action] = split(controllerAndAction, "#")
    :lists.append(routesList, [[method: method, path: path, controller: binary_to_atom(controller), action: binary_to_atom(action)]])
  end

  @doc """
    Create list with router path.
  """
  def on(method, path, controller, action) do
    [[method: method, path: path, controller: controller, action: action]]
  end

  def on(routesList, method, path, controller, action) do
    :lists.append(routesList, [[method: method, path: path, controller: controller, action: action]])
  end

  @doc """
    Resourcefull routing
  """
  def resources(controller) do
    resources_routes(controller)
  end

  def resources(routesList, controller) do
    routes = resources_routes(controller)
    :lists.append(routesList, routes)
  end

  @doc """
    Create redirect path
  """
  def redirect(method, path, redirect_path) do
    [[method: method, path: path, redirect_path: redirect_path]]
  end

  def redirect(routesList, method, path, redirect_path) do
    :lists.append(routesList, [[method: method, path: path, redirect_path: redirect_path]])
  end

  @doc """
    Match current url path. Is it web application route or not
  """
  def match_routes(path, routes, req_method) do
    parsed_path = getBinding(path)

    Enum.filter(routes,
      fn(route) ->
        case route do
          [method: method, path: p, controller: _controller, action: _action] ->
            case is_regex(p) do
              true ->
                case method do
                  "ANY" -> match_routes_regex_helper(p, path)
                  _ -> (match_routes_regex_helper(p, path) and (req_method == method))
                end
              false ->
                parsed_route_path = getBinding(p)
                case method do
                  "ANY" -> match_routes_helper(parsed_path, parsed_route_path)
                  _ -> (match_routes_helper(parsed_path, parsed_route_path) and (req_method == method))
                end
            end
          [method: method, path: p, redirect_path: _redirect_path] ->
            parsed_route_path = getBinding(p)
            case method do
              "ANY" -> match_routes_helper(parsed_path, parsed_route_path)
              _ -> (match_routes_helper(parsed_path, parsed_route_path) and (req_method == method))
            end
          end
      end) |> Enum.at(0) |> catch_nil
  end

  defp match_routes_regex_helper(path, regex) do
    Regex.match?(path, regex)
  end

  defp match_routes_helper([], []) do
    true
  end

  defp match_routes_helper([{_type, _path} | _parsed_path], []) do
    false
  end

  defp match_routes_helper([], [{_route_type, _route_path} | _parsed_route_path]) do
    false
  end

  defp match_routes_helper([{:param, _, _key, _val} | _parsed_path], []) do
    true
  end

  defp match_routes_helper([{type, path} | parsed_path], [{route_type, route_path} | parsed_route_path]) do
    case type == route_type do
      true ->
        (path == route_path) && match_routes_helper(parsed_path, parsed_route_path)
      false ->
        (route_type == :binding) && (path != <<>>) && match_routes_helper(parsed_path, parsed_route_path)
    end
  end

  defp match_routes_helper([{:param, _, _key, _val} | _parsed_path], [{_route_type, _route_path} | _parsed_route_path]) do
    true
  end

  defp resources_routes(controller) do
    url = List.foldl(String.split(atom_to_binary(controller),"."), "",
      fn (x, acc) ->
        case x do
         "Elixir" -> acc <> ""
         _ -> acc <> "/" <> x
        end
      end) |> String.downcase

    [[method: "GET",    path: url,                controller: controller, action: :index],
     [method: "GET",    path: url <> "/new",      controller: controller, action: :new],
     [method: "POST",   path: url,                controller: controller, action: :create],
     [method: "GET",    path: url <> "/:id",      controller: controller, action: :show],
     [method: "GET",    path: url <> "/:id/edit", controller: controller, action: :edit],
     [method: "PUT",    path: url <> "/:id",      controller: controller, action: :update],
     [method: "DELETE", path: url <> "/:id",      controller: controller, action: :destroy]]
  end

  defp catch_nil(list) when list == nil do
    []
  end

  defp catch_nil(list) do
    list
  end

end
