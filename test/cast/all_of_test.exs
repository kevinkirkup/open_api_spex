defmodule OpenApiSpex.CastAllOfTest do
  use ExUnit.Case
  alias OpenApiSpex.{Cast, Schema}
  alias OpenApiSpex.Cast.{Error, AllOf}
  alias OpenApiSpex.TestAssertions

  defp cast(ctx), do: AllOf.cast(struct(Cast, ctx))

  describe "cast/1" do
    test "allOf" do
      schema = %Schema{allOf: [%Schema{type: :integer}, %Schema{type: :string}]}
      assert {:ok, 1} = cast(value: "1", schema: schema)
      assert {:error, [error]} = cast(value: "one", schema: schema)

      assert Error.message(error) ==
               "Failed to cast value as integer. Value must be castable using `allOf` schemas listed."
    end

    test "allOf, uncastable schema" do
      schema = %Schema{allOf: [%Schema{type: :integer}, %Schema{type: :string}]}
      assert {:error, [error]} = cast(value: [:whoops], schema: schema)

      assert Error.message(error) ==
               "Failed to cast value as integer. Value must be castable using `allOf` schemas listed."

      schema_with_title = %Schema{allOf: [%Schema{title: "Age", type: :integer}]}

      assert {:error, [error_with_schema_title]} = cast(value: [:nopes], schema: schema_with_title)

      assert Error.message(error_with_schema_title) ==
               "Failed to cast value as Age. Value must be castable using `allOf` schemas listed."
    end

    test "a more sophisticated example" do
      dog = %{"bark" => "woof", "pet_type" => "Dog"}
      TestAssertions.assert_schema(dog, "Dog", OpenApiSpexTest.ApiSpec.spec())
    end

    test "allOf, for inheritance schema" do
      import ExUnit.CaptureIO

      defmodule NamedEntity do
        require OpenApiSpex
        alias OpenApiSpex.{Schema}

        OpenApiSpex.schema(%{
          title: "NamedEntity",
          description: "Anything with a name",
          type: :object,
          properties: %{
            name: %Schema{type: :string}
          },
          required: [:name]
        })
      end

      schema = %Schema{
        allOf: [
          NamedEntity,
          %Schema{
            type: :object,
            properties: %{
              id: %Schema{
                type: :string
              }
            }
          },
          %Schema{
            type: :object,
            properties: %{
              bar: %Schema{
                type: :string
              }
            }
          }
        ]
      }

      value = %{id: "e30aee0f-dbda-40bd-9198-6cf609b8b640", bar: "foo", name: "Elizabeth"}

      capture_io(:stderr, fn ->
        assert {:ok, %{id: "e30aee0f-dbda-40bd-9198-6cf609b8b640", bar: "foo"}} =
                 cast(value: value, schema: schema)
      end)
    end
  end

  test "allOf, for multi-type array" do
    schema = %Schema{
      allOf: [
        %Schema{type: :array, items: %Schema{type: :integer}},
        %Schema{type: :array, items: %Schema{type: :boolean}},
        %Schema{type: :array, items: %Schema{type: :string}}
      ]
    }

    value = ["Test #1", "2", "3", "4", "true", "Five!"]
    assert {:ok, [2, 3, 4, true, "Test #1", "Five!"]} = cast(value: value, schema: schema)
  end

  defmodule CatSchema do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Cat",
      allOf: [
        %Schema{
          type: :object,
          properties: %{
            fur: %Schema{type: :boolean}
          }
        },
        %Schema{
          type: :object,
          properties: %{
            meow: %Schema{type: :boolean}
          }
        }
      ]
    })
  end

  test "with schema having x-type" do
    value = %{fur: true, meow: true}
    assert {:ok, _} = cast(value: value, schema: CatSchema.schema())
  end
end
