defmodule GenProgram.Supervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(
      __MODULE__,
      [],
      name: GenProgram
    )
  end

  def start_child(program_name) do
    DynamicSupervisor.start_child(
      GenProgram,
      %{id: GenProgram,
        start: {GenProgram, :new, [program_name]}
      }
    )
  end
    
  @impl true
  def init [] do

    {:ok, _} =
      Registry.start_link(
        keys: :unique,
        name: ProgramRegistry
      )
    
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_children: 10 # Max of ten programs open at a time
    )
  end

end
