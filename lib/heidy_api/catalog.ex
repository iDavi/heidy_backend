defmodule HeidyApi.Catalog do
  @moduledoc """
  Read-only university reference data (universities, units, courses,
  disciplines). Served from the demo dataset until real seeding lands;
  the API never writes to it.
  """

  alias HeidyApi.Catalog.{Discipline, Unit, University}
  alias HeidyApi.{Demo, Page, Store}

  @type pagination :: %{
          :page => pos_integer(),
          :page_size => pos_integer(),
          optional(atom()) => term()
        }

  @spec search_universities(String.t() | nil, pagination()) :: Page.t()
  def search_universities(query, pagination) do
    Demo.catalog(:universities)
    |> filter_query(query, &"#{&1.name} #{&1.acronym}")
    |> paginate(pagination)
  end

  @spec fetch_university(String.t()) :: {:ok, University.t()} | {:error, :not_found}
  def fetch_university(id), do: Store.fetch(:universities, id)

  @spec list_units(University.t(), pagination()) :: Page.t()
  def list_units(%University{}, pagination) do
    paginate(Demo.catalog(:units), pagination)
  end

  @spec fetch_unit(String.t()) :: {:ok, Unit.t()} | {:error, :not_found}
  def fetch_unit(id), do: Store.fetch(:units, id)

  @spec list_courses(Unit.t(), pagination()) :: Page.t()
  def list_courses(%Unit{}, pagination) do
    paginate(Demo.catalog(:courses), pagination)
  end

  @spec search_disciplines(map(), pagination()) :: Page.t()
  def search_disciplines(filters, pagination) do
    Demo.catalog(:disciplines)
    |> filter_query(filters[:q], &"#{&1.code} #{&1.name}")
    |> paginate(pagination)
  end

  @spec fetch_discipline(String.t()) :: {:ok, Discipline.t()} | {:error, :not_found}
  def fetch_discipline(id), do: Store.fetch(:disciplines, id)

  defp filter_query(items, nil, _text), do: items

  defp filter_query(items, query, text) do
    downcased = String.downcase(query)
    Enum.filter(items, &String.contains?(String.downcase(text.(&1)), downcased))
  end

  defp paginate(items, %{page: page, page_size: page_size}) do
    Page.paginate(items, page, page_size)
  end
end
