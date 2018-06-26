defmodule GenProgram do
  @moduledoc """
  GenProgram is a gen_server used to create and save programs for 
  use with the ArduinoComm application.

  TODO: Add functions for converting and saving program steps.
        Add functions for saving and loading programs
        Add config parameters funs
        Add type parameter funs
  """

  defmodule Program do
    @moduledoc """
    The Program struct contains the following fields:
    
    program_name: The name of the program
    size: The current number of steps in the program
    creator: The creator/author of the program
    lights: The number of led lights used in the program
    config: The configuration of the lights (ring, strand, ...)
    type: The type and color range of the lights ({:addressable, :rgb}, {:single_color, :rgbw}, ...)
    """
    defstruct program_name: nil,
      program: [],
      size: nil,
      creator: nil,
      lights: nil,
      config: nil,
      type: nil
  end

  use GenServer
  alias GenProgram

  @doc """
  Adds a creator to the program's meta-data.
  """
  def add_creator(program_name, creator) do
    GenServer.cast(server(program_name),
      {:add_creator, creator}
    )
  end

  @doc """
  Returns the current program state and meta-data.
  """
  def get_state(program_name) do
    GenServer.call(server(program_name), :get_state)
  end

  
  @doc """
  Starts a new GenServer for building a program.
  """
  def new program_name do
    GenServer.start_link(
      __MODULE__,
      program_name,
      name: server(program_name)
    )
  end

  @doc """
  Initializes the GenProgram state with the Program struct
  and assigns the program_name.
  """
  def init program_name do
    {:ok,
     %Program{program_name: program_name}
    }
  end


  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  def handle_cast({:add_creator, name}, state) do
    {:noreply, %{state | creator: name}}
  end


  
  defp server(name), do: {:via, Registry, {ProgramRegistry, name}}

end


