defmodule DashboardGen.CSVUtils do
  alias NimbleCSV.RFC4180, as: CSV

  def melt_wide_to_long(path, x_field, y_fields) do
    [headers | rows] = path |> File.read!() |> CSV.parse_string()

    Enum.flat_map(rows, fn row ->
      Enum.flat_map(y_fields, fn y_field ->
        month = get_value(headers, row, x_field)
        value = get_value(headers, row, y_field)

        if is_nil(month) or is_nil(value) do
          []
        else
          [
            %{
              x: month,
              value: parse_number(value),
              category: y_field
            }
          ]
        end
      end)
    end)
  end

  defp get_value(headers, row, field) do
    case Enum.find_index(headers, &(&1 == field)) do
      nil -> nil
      index -> Enum.at(row, index)
    end
  end

  defp parse_number(str) when is_binary(str) do
    case Float.parse(str) do
      {num, _} -> num
      _ -> 0
    end
  end

  defp parse_number(_), do: 0
end
