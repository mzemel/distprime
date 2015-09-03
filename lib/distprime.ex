defmodule DistPrime do
  use Application

  def start(_type, finish) do
    DistPrime.Supervisor.start_link(finish)
  end
end

defmodule DistPrime.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(args) do
    child_processes = [
      worker(DistPrime.Collector, []),
      supervisor(DistPrime.WorkerScheduler, args)
    ]
    supervise child_processes, strategy: :one_for_one
  end
end

defmodule DistPrime.Collector do
  use GenServer

  @moduledoc """
  Singleton collection server that worker processes will send primes to
  """

  #####
  # External API
  def start_link do
    IO.puts "Collector started"
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_prime(p) do
    GenServer.cast(__MODULE__, {:add_prime, p})
  end

  def nth_prime(n) do
    GenServer.call(__MODULE__, {:nth_prime, n})
  end

  def size do
    GenServer.call(__MODULE__, :size)
  end

  #####
  # GenSever implementation

  def handle_cast({:add_prime, p}, state) do
    {:noreply, [p | state]}
  end

  def handle_call({:nth_prime, n}, _from, state) do
    nth = state
          |> Enum.sort
          |> Enum.at(n - 1, :none)

    {:reply, nth, state}
  end

  def handle_call(:size, _from, state) do
    {:reply, Enum.count(state), state}
  end

  def init(_) do
    {:ok, []}
  end

end

defmodule DistPrime.WorkerScheduler do
  use Supervisor

  def start_link(args) do
    IO.puts "Worker scheduler started"
    Supervisor.start_link(__MODULE__, args)
  end

  def init(finish) do
    1..finish
    |> Enum.chunk(1000)
    |> Enum.map(&(worker(DistPrime.Worker, [&1], id: Enum.at(&1, 0), restart: :transient)))
    |> supervise(strategy: :one_for_one)
      
  end
end

defmodule DistPrime.Worker do
  alias DistPrime
  #####
  # External API

  def start_link(range) do
    Task.start_link(__MODULE__, :compute_range, [range])
  end

  def is_prime?(2) do
    true
  end

  def is_prime?(n) do
    Enum.to_list(2..round(:math.sqrt(n)))
    |> Enum.any?(fn (x) -> rem(n, x) == 0 end)
    |> Kernel.not
  end

  def compute_range(range) do
    range
    |> Enum.filter( fn(n)-> is_prime?(n) end)
    |> Enum.map &(DistPrime.Collector.add_prime(&1))
  end
end