defmodule ProgramDB do
  @moduledoc """
  This module defines the functions that interface with the
  ets table that stores the programs by name.

  TODO: get random program?
  """

  @doc """
  Checks the application environment for a saved program 
  file and loads it if found. Otherwise creates a new ets 
  table.
  """
  def new do
    # Look in environment for file containing saved programs
    case Application.fetch_env(:arduino_comm, :program_file) do
      :error ->
        # No program store defined so create a new one.
        IO.puts("No program file specified in application configuration. Creating new one.")
        
        # TODO: Maybe switch table to :protected
        {:ok,
         :ets.new(__MODULE__,
           [
             :public,
             {:read_concurrency, true}
           ])
        }
        
      {:ok, file_name} ->
        # Program store exists so load it.
        IO.puts("Loading #{file_name}.")
        
        file_name
        |> to_charlist
        |> :ets.file2tab
    end
  end
  

  @doc """
  Saves the program under name in the database. Returns :ok
  if program is added to ets table or {:error, :eexist} if
  the program name already exists in the table.


  This function does not save the updated ets table to disk.
  Consider calling save/1, save/2, or save/3 after all changes.
  """
  def add_new_program(table, name, program) do
    unless :ets.insert_new(table, {name, program}) do
      IO.puts("Program already exists.")
      {:error, :eexist}
    end
    
    :ok
  end


  @doc """
  Saves the program under name in the ets table. Overwrites
  any existing programs of the given name.

  This function does not save the updated ets table to disk.
  Consider calling save/1, save/2, or save/3 after all changes.
  """
  def add_program(table, name, program) do
    :ets.insert(table, {name, program})
  end


  @doc """
  Delete the program from the ets table.

  This function does not update the file saved on disk.
  If that is intended, call save/1, save/2, or save/3 after all 
  changes have been made.
  """
  def delete_program(table, name) do
    :ets.delete(table, name)
  end

  
  @doc """
  Looks up the given program name in the table.
  If found, {:ok, program} is returned.
  If not found, {:error, :not_found} is returned.
  Otherwise, {:error, :multiple} is returned.
  """
  def lookup(table, name) do
    case :ets.lookup(table, name) do
      [] ->
        {:error, :not_found}
      [{^name, program}] ->
        {:ok, program}
      other ->
        # This shouldn't happen
        IO.inspect("Found multiple programs under that name: #{other}")
        {:error, :multiple}
    end
  end
  

  @doc """
  Returns true if the key is present in the table and
  false otherwise.
  """
  def exists?(table, name), do: :ets.member(table, name)
  

  @doc """
  Returns a list of all loaded programs.
  """
  def loaded table do
    :ets.match(table, {'$1', '_'})
  end

  
  @doc """
  Saves the current list of programs under an application
  environment defined file name and location. Use save/1
  to save the list of programs under a different name and
  save/2 to save the programs in a different location.
  """
  def save table do
    case Application.fetch_env(:arduino_comm, :program_file) do
      :error ->
        # No file name / location is set.
        IO.puts("No program file name specified in application configuration.")
        {:error, :einval}

      {:ok, file_name} ->
        # Try to save at the default location.
        save(table, file_name)
    end
  end

  @doc """
  Saves the program list under the given name in the default directory.
  """
  def save(table, file_name) do
    location = Application.get_env(:arduino_comm, :save_location, File.cwd!)
    save(table, file_name, location)
  end


  @doc """
  Saves the program list under the given name and directory.
  """
  def save(table, file_name, directory) do
    path =
      Path.join(directory, file_name)
      |> to_charlist
    # path has to be a character list because Erlang
    
    IO.puts("Saving programs at #{path}")
    :ets.tab2file(table, path)
  end


  @doc """
  Loads the program file from the default directory into the table. 
  Programs with matching names are overwritten.
  """
  def load(table, file_name) do
    load(table, file_name, File.cwd!)
  end

  @doc """
  Loads the program file into the table. Programs with matching names are
  overwritten.
  """
  def load(table, file_name, location) do
    path = Path.join(location, file_name)
    
    {:ok, loaded} =
      path
      |> to_charlist
      |> IO.inspect
      |> :ets.file2tab
   
    :ets.foldl(
      fn(program, acc) ->
        :ets.insert(acc, program)
        acc
      end,
      table, loaded)
  end

  @doc """
  Loads the program file from the default directory into the table. 
  Only new programs are loaded into the table.
  """
  def load_new(table, file_name) do
    load_new(table, file_name, File.cwd!)
  end

  @doc """
  Loads the program file into the table. 
  Only new programs are loaded into the table.
  """
  def load_new(table, file_name, location) do
    path = Path.join(location, file_name)
    
    {:ok, loaded} =
      path
      |> to_charlist
      |> IO.inspect
      |> :ets.file2tab
   
    :ets.foldl(
      fn(program, acc) ->
        :ets.insert_new(acc, program)
        acc
      end,
      table, loaded)
  end
  
end
