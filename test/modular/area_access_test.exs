defmodule Modular.AreaAccessTest do
  use Modular.CheckCase

  @described_check Modular.AreaAccess

  test "allow external area's interface access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Sales do
        def sell_products do
          Invoicing.create_invoice(products)
        end
      end
    """

    [source_file]
    |> to_source_files
    |> refute_issues(@described_check)
  end

  test "forbid external area's implementation access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Sales do
        def sell_products do
          Invoicing.CreateInvoiceService.call(products)
        end
      end
    """

    [source_file]
    |> to_source_files
    |> assert_issue(@described_check)
  end

  test "ignore non-existing module access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Sales do
        def sell_products do
          Invoicing.CreateInvoiceServiceTYPO.call(products)
        end
      end
    """

    [source_file]
    |> to_source_files
    |> refute_issues(@described_check)
  end

  test "ignore access to module without @moduledoc" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        # @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Sales do
        def sell_products do
          Invoicing.CreateInvoiceService.call(products)
        end
      end
    """

    [source_file]
    |> to_source_files
    |> refute_issues(@described_check)
  end

  test "allow nested area's interface access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          Invoicing.Invoice.build()
          :ok
        end
      end

      defmodule Invoicing.Invoice do
        @moduledoc "Represents an issued invoice."

        defstruct [:id, :items, :number]
      end

      defmodule Invoicing.Invoice.GenerateNumber do
        @moduledoc false

        def call do
          # ...
        end
      end
    """

    [source_file]
    |> to_source_files
    |> refute_issues(@described_check)
  end

  test "forbid nested area's implementation access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          Invoicing.Invoice.GenerateNumber.call()
          :ok
        end
      end

      defmodule Invoicing.Invoice do
        @moduledoc "Represents an issued invoice."

        defstruct [:id, :items, :number]
      end

      defmodule Invoicing.Invoice.GenerateNumber do
        @moduledoc false

        def call do
          # ...
        end
      end
    """

    [source_file]
    |> to_source_files
    |> assert_issue(@described_check)
  end

  test "allow parent area's interface access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Invoicing.Invoice do
        @moduledoc "Represents an issued invoice."

        defstruct [:id, :items, :number]
      end

      defmodule Invoicing.Invoice.GenerateNumber do
        @moduledoc false

        def call do
          Invoicing.create_invoice([])
        end
      end
    """

    [source_file]
    |> to_source_files
    |> refute_issues(@described_check)
  end

  test "forbid parent area's implementation access" do
    source_file = """
      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."
      end

      defmodule Invoicing.CreateInvoiceService do
        @moduledoc false

        def call(items) do
          :ok
        end
      end

      defmodule Invoicing.Invoice do
        @moduledoc "Represents an issued invoice."

        defstruct [:id, :items, :number]
      end

      defmodule Invoicing.Invoice.GenerateNumber do
        @moduledoc false

        def call do
          Invoicing.CreateInvoiceService.call([])
        end
      end
    """

    [source_file]
    |> to_source_files
    |> assert_issue(@described_check)
  end
end
