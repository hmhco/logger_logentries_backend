defmodule Output.Test do
  @logfile "test_log.log"

  def transmit(_host, _port, message) do
    File.write!(@logfile, message)
  end

  def read() do
    if exists() do
      File.read!(@logfile)
    end
  end

  def exists() do
    File.exists?(@logfile)
  end

  def destroy() do
    if exists() do
      File.rm!(@logfile)
    end
  end
end

defmodule Logger.Backend.Logentries.Test do
  use ExUnit.Case, async: false
  require Logger

  @backend {Logger.Backend.Logentries, :test}
  Logger.add_backend @backend

  setup do
    config([
      connector: Output.Test,
      host: 'logentries.url',
      port: 10000,
      format: "[$level] $message\n",
      token: "<<logentries-token>>"
    ])
    on_exit fn ->
      connector.destroy()
    end
    :ok
  end

  test "default logger level is `:debug`" do
    assert Logger.level() == :debug
  end

  test "does not log when level is under minimum Logger level" do
    config(level: :info)
    Logger.debug("do not log me")
    refute connector().exists()
  end

  test "does log when level is above or equal minimum Logger level" do
    refute connector().exists()
    config(level: :info)
    Logger.warn("you will log me")
    assert connector().exists()
    assert read_log() == "[warn] you will log me <<logentries-token>>\n"
  end

  test "can configure format" do
    config format: "$message ($level)\n"

    Logger.info("I am formatted")
    assert read_log() == "I am formatted <<logentries-token>> (info)\n"
  end

  test "can configure metadata" do
    config format: "$metadata$message\n", metadata: [:user_id, :auth]

    Logger.info("hello")
    assert read_log() == "hello <<logentries-token>>\n"

    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.info("hello")
    assert read_log() == "user_id=13 auth=true hello <<logentries-token>>\n"
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end

  defp connector() do
    {:ok, connector} = GenEvent.call(Logger, @backend, :connector)
    connector
  end

  defp read_log() do
    connector().read()
  end
end
