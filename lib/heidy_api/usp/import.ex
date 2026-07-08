defmodule HeidyApi.Usp.Import do
  @moduledoc """
  The anti-corruption mappers: USP records in, `HeidyApi.Planner` attribute
  maps out. Nothing downstream of this module knows what a `codtur` is.

  Every mapped row carries `source: "usp"` and an `external_ref`, so
  re-syncs upsert instead of duplicating and manual rows are never touched.
  """

  alias HeidyApi.Usp.{ClassSlot, EnrollmentRecord}

  @doc ~S"""
  Maps a USP period code to semester attributes.

      iex> HeidyApi.Usp.Import.semester_attrs("20261").label
      "2026.1"
  """
  @spec semester_attrs(String.t()) :: map()
  def semester_attrs(<<year::binary-4, half::binary-1>> = period) do
    {start_date, end_date} =
      case half do
        "1" -> {Date.from_iso8601!("#{year}-02-01"), Date.from_iso8601!("#{year}-07-15")}
        _second -> {Date.from_iso8601!("#{year}-08-01"), Date.from_iso8601!("#{year}-12-20")}
      end

    %{
      label: "#{year}.#{half}",
      start_date: start_date,
      end_date: end_date,
      source: "usp",
      external_ref: period
    }
  end

  @doc "Maps schedule slots to enrollment attributes, one per class, with meetings."
  @spec enrollments_from_schedule([ClassSlot.t()]) :: [map()]
  def enrollments_from_schedule(slots) do
    slots
    |> Enum.group_by(&{&1.discipline_code, &1.class_code})
    |> Enum.map(fn {{discipline_code, class_code}, class_slots} ->
      %{
        title: discipline_code,
        source: "usp",
        external_ref: external_ref(discipline_code, class_code),
        meetings: Enum.map(class_slots, &meeting_attrs/1)
      }
    end)
  end

  @doc "Maps a period enrollment record to enrollment attributes."
  @spec enrollment_attrs(EnrollmentRecord.t()) :: map()
  def enrollment_attrs(%EnrollmentRecord{} = record) do
    %{
      title: "#{record.discipline_code} #{record.discipline_name}",
      source: "usp",
      external_ref: external_ref(record.discipline_code, record.class_code)
    }
  end

  @doc "Maps a schedule slot to meeting attributes."
  @spec meeting_attrs(ClassSlot.t()) :: map()
  def meeting_attrs(%ClassSlot{} = slot) do
    %{day_of_week: slot.day_of_week, starts_at: slot.starts_at, ends_at: slot.ends_at}
  end

  defp external_ref(discipline_code, nil), do: discipline_code
  defp external_ref(discipline_code, class_code), do: "#{discipline_code}-#{class_code}"
end
