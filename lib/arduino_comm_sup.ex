defmodule ArduinoComm.Sup do
  use Supervisor

  
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args,
      [name: __MODULE__])
  end

  
  def init(args) do
    ## Initialize the Program Database
    ## Either creates a new table or loads one from the config file.
    {:ok, db_ref} = ProgramDB.new()

    flags = %{
      strategy: :one_for_one
    }
    
    arduino = [
      %{id: CommStateM,
        start: {CommStateM, :connect, [db_ref | args]}
       }
    ]

    {:ok, {flags, arduino}}
    
    
  end

  
  def stop(reason) do
    Supervisor.stop(CommStateM, reason, :infinity)
  end

  
end
