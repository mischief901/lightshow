defmodule ArduinoComm do
  use Application

  def start(_type, _args) do
    ArduinoComm.Sup.start_link([])
  end
  
end
