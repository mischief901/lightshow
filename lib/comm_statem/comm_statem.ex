defmodule CommStateM do
  use GenStateMachine, callback_mode: :state_functions
  
  defmodule Data do
    defstruct program: [],
      # Will be a list of binary program steps
      program_name: nil,
      # Name of the currently executing program
      queue: [],
      # Will be a list of program names
      arduino_name: nil,
      # Will be a string with the port name (i.e. ttyACM0)
      comm_pid: nil,
      # The pid of the Nerves.UART connection to the arduino
      program_db: nil
    # The table identifier or other identifier for the
    # program database
  end
  
  alias CommStateM

  ## The type value for setting staged changes on the arduino.
  @set 2
  
  ## The type value for turning off all the leds on the arduino
  @clear_all 3
  
  
  @doc """
  Connect/1 starts the GenStateMachine process. 
  Returns :ok | {:error, reason}.
  """
  def connect db_ref do
    start_link(db_ref)
  end

  @doc """
  Connect/2 starts the GenStateMachine process and tries to connect to the
  given Arduino. Equivalent to calling connect/1 and then add_arduino/1.
  Returns :ok | {:error, reason}.
  """
  def connect(db_ref, port_name) do
    {:ok, _pid} = start_link(db_ref)
    add_arduino(port_name)
  end


  @doc """
  Connect/3 starts the GenStateMachine process, tries to connect to the given
  Arduino, and tries to load the given program. Equivalent to calling connect/1,
  add_arduino/1, and load_program/1.
  Returns :ok | {:error, reason}.
  """
  def connect(db_ref, port_name, program_name) do
    {:ok, _pid} = start_link(db_ref)
    :ok = add_arduino(port_name)
    load_program(program_name)
  end
  
  
  @doc """
  Adds the arduino at the given port name (i.e. "ttyACM0") to the state machine.
  """
  def add_arduino port_name do
    GenStateMachine.call(__MODULE__, {:add, port_name})
  end

  
  @doc """
  Gets the list of all active arduinos running on the state machine.
  """  
  def get_arduino_list do
    GenStateMachine.call(__MODULE__, :get_all)
  end

  
  @doc """
  Loads the program to the arduino immediately, replacing any current
  program. A program must be loaded prior to running.
  Returns :ok | {:error, reason}
  """
  def load_program program_name do
    GenStateMachine.call(__MODULE__, {:load, program_name})
  end

  
  @doc """
  Queues the next program to play after the current one is complete. 
  Queueing a program does not load the program for running.
  If the program does not exist, returns {:error, :enoent}. Otherwise :ok.
  """
  def queue_program name do
    GenStateMachine.call(__MODULE__, {:queue, name})
  end

  
  @doc """
  Ends the current running program. Effectively turns off the leds and hibernates
  the state machine.
  """
  def end_program do
    GenStateMachine.cast(__MODULE__, :end_program)
  end

  
  @doc """
  Ends the current running program, clears the leds, and begins the next 
  queued program. If no program is queued, the state machine pauses.
  """
  def next_program do
    :ok = GenStateMachine.call(__MODULE__, :next_program)
    GenStateMachine.cast(__MODULE__, :run)
  end


  @doc """
  Runs the currently loaded program. If a program is not
  loaded or an error occurs, nothing happens.
  """
  def run do
    GenStateMachine.cast(__MODULE__, :run)
  end

  
  @doc """
  Ceases communication with the Arduino and shuts down the related processes
  and state machine.
  """
  def shutdown do
    GenStateMachine.stop(__MODULE__, :normal)
  end


  @doc """
  Saves the program database to file.
  """
  def save(file_name) do
    GenStateMachine.call(__MODULE__, {:save, file_name})
  end

  @doc """
  Saves the program database to file in the given directory.
  """
  def save(file_name, directory) do
    GenStateMachine.call(__MODULE__, {:save, file_name, directory})
  end

  
  @doc """
  Loads the program file into memory.
  """
  def load(file_name) do
    GenStateMachine.call(__MODULE__, {:load_file, file_name})
  end

  @doc """
  Loads the program file from the given directory into memory.
  """
  def load(file_name, directory) do
    GenStateMachine.call(__MODULE__, {:load_file, file_name, directory})
  end

  
  ## End of API
  
  
  @doc """
  Starts the Gen State Machine process and the UART port in state open.
  Does not connect to an Arduino or load a program.
  """
  def start_link(db_ref) do
    GenStateMachine.start_link(__MODULE__, [db_ref], [name: __MODULE__])
  end

  
  @doc """
  Starts the Nerves.UART gen server for communicating with the Arduino.
  """
  def init([db_ref]) do
    {:ok, pid} = Nerves.UART.start_link
    {:ok, :open, %Data{program_db: db_ref, comm_pid: pid}}
  end


  @doc """
  Common events like getting the list of arduinos, loading, and saving files
  are handled in the handle_common function. There is no change in state or 
  data resulting from these calls.
  """
  def handle_common({:call, from},
    :get_all,
    _state,
    _data) do
    
    {:keep_state_and_data,
     {:reply, from, Nerves.UART.enumerate()}
    }
  end

  def handle_common({:call, from},
    {:save, file_name},
    _state,
    data) do
    
    res = ProgramDB.save(data.program_db, file_name)
    {:keep_state_and_data,
     {:reply, from, res}
    }
  end
  
  def handle_common({:call, from},
    {:save, file_name, directory},
    _state,
    data) do

    res = ProgramDB.save(data.program_db, file_name, directory)
    {:keep_state_and_data,
     {:reply, from, res}
    }    
  end    

  def handle_common({:call, from},
    {:load_file, file_name},
    _state,
    data) do
    
    res = ProgramDB.load(data.program_db, file_name)
    {:keep_state_and_data,
     {:reply, from, res}
    }
  end
  
  def handle_common({:call, from},
    {:load_file, file_name, directory},
    _state,
    data) do

    res = ProgramDB.load(data.program_db, file_name, directory)
    {:keep_state_and_data,
     {:reply, from, res}
    }    
  end

  def handle_common({:call, from}, message, state, data) do
    ## For debugging purposes do not crash and just keep
    ## the state and data. TODO: Crash on invalid message.
    IO.inspect("Received invalid message in #{state}: #{inspect message}")
    IO.inspect("Current Data: #{inspect data}")
    {:keep_state_and_data,
     {:reply, from, {:error, :einval}}
    }
  end

  def handle_common(_, message, state, data) do
    ## For debugging purposes do not crash and just keep
    ## the state and data. TODO: Crash on invalid message.
    IO.inspect("Received invalid message in #{state}: #{inspect message}")
    IO.inspect("Current Data: #{inspect data}")
    :keep_state_and_data
  end
  
  @doc """
  The open state allows for an arduino to connect. On
  successful connection the state machine transitions to
  the connected state. Errors reply with {:error, reason},
  but do not transition states or exit.

  Valid state calls are from add_arduino and get_arduino_list.
  """
  def open({:call, from}, {:add, port_name}, data) do
    case Nerves.UART.open(data.comm_pid, port_name) do
      :ok ->
        ## Successfully Connected
        GenStateMachine.reply(from, :ok)
        {
          :next_state,
          :connected,
          %{data | arduino_name: port_name}
        }
        
      {:error, reason} ->
        ## There is an error opening the port.
        ## Just keep the state and reply with the error.
        GenStateMachine.reply(from, {:error, reason})
        :keep_state_and_data
    end
  end

  def open(type, message, data) do
    handle_common(type, message, :open, data)
  end

  
  @doc """
  The connected state allows for the loading of a program. 
  On successful loading the state machine transitions to
  the ready state. Errors reply with {:error, reason},
  but do not transition states or exit.

  Valid state calls are load_program, queue_program, and
  get_arduino_list.
  """
  def connected({:call, from},
    {:load, program_name},
    %Data{program_db: db} = data) do
    
    {:ok, program} = ProgramDB.lookup(db, program_name)
    {
      :next_state,
      :ready,
      %{data | program: program},
      [{:reply, from, :ok}]
    }
  end

  def connected({:call, from},
    {:queue, program_name},
    %Data{program_db: db} = data) do
    
    if ProgramDB.exists?(db, program_name) do
      {:keep_state,
       %{data | queue: data.queue ++ [program_name]},
       [{:reply, from, :ok}]
      }
    else
      {:keep_state_and_data,
       [{:reply, from, {:error, :eexist}}]
      }
    end
  end
  
  def connected(type, message, data) do
    handle_common(type, message, :connected, data)
  end  

  @doc """
  The ready state allows for the loading and running of a 
  program. On success the state machine 
  transitions to the running state. Errors reply with 
  {:error, reason}, but do not transition states or exit.

  Valid state calls are load_program, queue_program, run, 
  and get_arduino_list.
  """
  def ready(:cast,:run,
    %Data{
      program: program,
      comm_pid: pid
    } = data) do

    # TODO: Substitute with custom function to send bytes
    # equal to the size of the receive buffer in the Arduino.
    {queue, rest} = Enum.split(program, 10)

    # Don't need the result of write, but I do want to make
    # sure it returned ok.
    queue
    |> Enum.each(&(:ok = Nerves.UART.write(pid, &1)))
    
    {:next_state, :running, %{data | program: rest}}
  end

  def ready({:call, from},
    {:load, program_name},
    %Data{program_db: db} = data) do
    
    {:ok, program} = ProgramDB.lookup(db, program_name)
    {
      :keep_state,
      %{data | program: program},
      [{:reply, from, :ok}]
    }
  end

  def ready({:call, from},
    {:queue, program_name},
    %Data{program_db: db} = data) do
    
    if ProgramDB.exists?(db, program_name) do
      {:keep_state,
       %{data | queue: data.queue ++ [program_name]},
       [{:reply, from, :ok}]
      }
    else
      {:keep_state_and_data,
       [{:reply, from, {:error, :eexist}}]
      }
    end
  end

  def ready(type, message, data) do
    handle_common(type, message, :ready, data)
  end

  @doc """
  The running state is responsible for running the loaded 
  program to completion. When the program is completed, the
  running state either loads and runs the next program in
  the queue or transitions back to the ready state.
  Errors reply with {:error, reason}, but do not transition
  states or exit.

  Valid state calls are load_program, queue_program,
  next_program, end_program, and get_arduino_list.
  """
  def running({:call, from},
    :next_program,
    %Data{queue: []}
  ) do
    {:keep_state_and_data,
     [{:reply, from, {:error, :not_found}}]
    }
  end

  def running({:call, from},
    :next_program,
    %Data{
      queue: [next | rest],
      comm_pid: pid,
      program_db: db
    } = data
  ) do

    # Load next program from the database
    {:ok, program} = ProgramDB.lookup(db, next)
    
    # Reconfigure the connection to inactive.
    Nerves.UART.configure(pid, active: false)
    
    # Drain all sending data
    Nerves.UART.drain(pid)

    # Flush and ignore all received acks from the Arduino
    Nerves.UART.flush(pid)

    # Reconfigure back to active connection.
    Nerves.UART.configure(pid, active: true)
    
    {:keep_state,
     %{data | program: program, queue: rest},
     [{:reply, from, :ok}]
    }
  end

  def running(:cast, :end_program,
    %Data{comm_pid: pid} = data) do
    
    Nerves.UART.configure(pid, active: false)
    Nerves.UART.drain(pid)
    Nerves.UART.write(pid, <<@clear_all::size(8)>>)
    Nerves.UART.flush(pid)
    Nerves.UART.configure(pid, active: true)
    
    {:next_state, :ready, %{data | program: []}}
  end

  def running({:call, from},
    {:load, program_name},
    %Data{
      comm_pid: pid,
      program_db: db
    } = data) do
    
    {:ok, program} = ProgramDB.lookup(db, program_name)
    Nerves.UART.write(pid, <<@clear_all::size(8)>>)
    Nerves.UART.flush(pid)
    
    {
      :keep_state,
      %{data | program: program},
      [{:reply, from, :ok}]
    }
  end

  def running({:call, from},
    {:queue, program_name},
    %Data{program_db: db} = data) do
    
    if ProgramDB.exists?(db, program_name) do
      {:keep_state,
       %{data | queue: data.queue ++ [program_name]},
       [{:reply, from, :ok}]
      }
    else
      {:keep_state_and_data,
       [{:reply, from, {:error, :eexist}}]
      }
    end
  end
  
  ## Basic flow control is implemented by responding to the
  ## Serial.println from the Arduino indicating which step
  ## was just executed.
  ## The state machine then writes the next step in the
  ## program.
  def running(:info,
    {:nerves_uart, arduino_name, {:error, reason}},
    _data) do

    IO.inspect("Error communicating with #{arduino_name}")
    IO.inspect("Reason: #{reason}")
    {:keep_state_and_data,
     [{{:timeout, :resend}, 50, {:check, <<@set::size(8)>>}}]
    }
  end

  def running(:info,
    {:nerves_uart, _arduino_name, _message_id},
    %Data{
      comm_pid: pid,
      program: [],
      queue: [next | rest],
      program_db: db
    } = data) do
    # Current program is finished, so load next in the queue and send.
    {:ok, program} = ProgramDB.lookup(db, next)
    # Write a clear all to the arduino between programs.
    Nerves.UART.write(pid, <<@clear_all::size(8)>>)
    
    {:keep_state, %{data | program: program, queue: rest}}
  end
  
  def running(:info,
    {:nerves_uart, arduino_name, message_id},
    %Data{
      comm_pid: pid,
      program: [next | rest]
    } = data) do

    IO.inspect("Received ack for #{message_id} from #{arduino_name}")
    
    Nerves.UART.write(pid, next)
    {:keep_state, %{data | program: rest}}
  end

  ## Did not receive a response from the Arduino.
  ## Send a blank message to check if reconnected.
  def running({:timeout, :resend},
    {:message, message},
    %Data{comm_pid: pid,
          program: program
    } = data) do

    case Nerves.UART.write(pid, message) do
      :ok ->
        ## Successfully reconnected. Re-fill buffer and
        ## continue execution.
        # TODO: Switch to custom function for splitting program.
        {buffer, queue} = Enum.split(program, 10)
        
        buffer
        |> Enum.each(&(:ok = Nerves.UART.write(pid, &1)))
        
        {:keep_state, %{data | program: queue}}

      {:error, reason} ->
        IO.inspect("Still not connected: #{reason}")
        ## reset timer
        {:keep_state_and_data,
         [{{:timeout, :resend}, 50, {:check, message}}]
        }
    end
  end

  def running(type, message, data) do
    handle_common(type, message, :running, data)
  end
  
  
  @doc """
  Typical code change function.
  """
  def code_change(_old, state, data, _extra) do
    {:ok, state, data}
  end

  
  @doc """
  Terminate writes a clear all to the arduino, stops the
  Nerves.UART gen server, and stops the current state 
  machine process.
  """
  def terminate(reason, _state, %{comm_pid: pid}) do
    Nerves.UART.write(pid, <<@clear_all::size(8)>>)
    Nerves.UART.drain(pid)
    Nerves.UART.stop(pid)
    {:stop, reason}
  end
  
end
