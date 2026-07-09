defmodule HeidyApi.Usp.ImportTest do
  use ExUnit.Case, async: true

  alias HeidyApi.Usp.{ClassSlot, EnrollmentRecord, Import}

  test "maps USP period codes to semester attributes" do
    assert %{
             label: "2026.1",
             start_date: ~D[2026-02-01],
             end_date: ~D[2026-07-15],
             source: "usp",
             external_ref: "20261"
           } = Import.semester_attrs("20261")
  end

  test "groups schedule slots into one enrollment per class with meeting attrs" do
    slots = [
      %ClassSlot{
        discipline_code: "ACH2016",
        class_code: "2026104",
        day_of_week: 2,
        starts_at: ~T[19:00:00],
        ends_at: ~T[20:45:00]
      },
      %ClassSlot{
        discipline_code: "ACH2016",
        class_code: "2026104",
        day_of_week: 4,
        starts_at: ~T[19:00:00],
        ends_at: ~T[20:45:00]
      }
    ]

    assert [
             %{
               title: "ACH2016",
               source: "usp",
               external_ref: "ACH2016-2026104",
               meetings: meetings
             }
           ] = Import.enrollments_from_schedule(slots)

    assert Enum.map(meetings, & &1.day_of_week) == [2, 4]
  end

  test "maps enrollment records without class codes to stable external refs" do
    record = %EnrollmentRecord{
      period: "20261",
      discipline_code: "MAC0110",
      discipline_name: "Introducao a Computacao",
      class_code: nil
    }

    assert %{
             title: "MAC0110 Introducao a Computacao",
             source: "usp",
             external_ref: "MAC0110"
           } = Import.enrollment_attrs(record)
  end
end
