defmodule Handler.WeberReqHandler.Default do

  defp request({:render_inline, data, params}, _app) do
    {:render, 200, (EEx.eval_string data, assigns: params), []}
  end

  defp request({:file, path, headers}, _app) do
    {:ok, file_content} = File.read(path)
    case :lists.keyfind("content-type", 1, headers) do
      false -> {:file, 200, file_content, :lists.append([{"content-type", "application/octet-stream"}], headers)}
      _ ->
        {:file, 200, file_content, headers}
    end
  end

  defp request({:redirect, location}, _app) do
    {:redirect, 302, "", [{"Location", location}]}
  end

  defp request({:nothing, headers}, _app) do
    {:nothing, 200, "", headers}
  end

  defp request({:text, data}, _app) do
    {:text, 200, data, []}
  end

  defp request({:text, data, headers}, _app) do
    {:text, 200, data, headers}
  end

  defp request({:json, data}, app) do
    request({:json, data, []}, app)
  end

  defp request({:json, data, headers}, _app) do
    {:json, 200, ExJSON.generate(data), :lists.append([{"Content-Type", "application/json"}], headers)}
  end

  defp request({:not_found, data, _headers}, _app) do
    {:not_found, 404, data, [{"Content-Type", "text/html"}]}
  end

end
