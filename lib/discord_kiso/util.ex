defmodule DiscordKiso.Util do
  require Logger

  def pull_id(message) do
    id = Regex.run(~r/([0-9])\w+/, message)

    case id do
      nil -> nil
      id -> List.first(id)
    end
  end

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def danbooru(tag1, tag2) do
    dan = "danbooru.donmai.us"
    blacklist = ["what", "scat", "guro", "gore", "loli", "shota"]

    IO.inspect {tag1, tag2}

    safe1 = Enum.member?(blacklist, tag1)
    safe2 = Enum.member?(blacklist, tag2)

    IO.inspect {safe1, safe2}

    {tag1, tag2} = case {safe1, safe2} do
      {_, true}       -> {"shangguan_feiying", "meme"}
      {true, _}       -> {"shangguan_feiying", "meme"}
      {false, false}  -> {tag1, tag2}
    end

    IO.inspect {tag1, tag2}

    tag1 = tag1 |> String.split |> Enum.join("_") |> URI.encode_www_form
    tag2 = tag2 |> String.split |> Enum.join("_") |> URI.encode_www_form

    request = "http://#{dan}/posts.json?limit=50&page=1&tags=#{tag1}+#{tag2}" |> HTTPoison.get!

    try do
      results = Poison.Parser.parse!((request.body), keys: :atoms)
      result = results |> Enum.shuffle |> Enum.find(fn post -> is_image?(post.file_url) == true && is_dupe?("dan", post.file_url) == false end)

      post_id = Integer.to_string(result.id)
      image = "http://#{dan}#{result.file_url}"

      {post_id, image, result}
    rescue
      Enum.EmptyError -> "Nothing found!"
      UndefinedFunctionError -> "Nothing found!"
      error ->
        Logger.log :warn, error
        "fsdafsd"
    end
  end

  def download(url) do
    filename = url |> String.split("/") |> List.last
    filepath = "_tmp/#{filename}"

    Logger.log :info, "Downloading #{filename}..."
    image = url |> HTTPoison.get!
    File.write filepath, image.body

    filepath
  end

  def is_dupe?(source, filename) do
    Logger.info "Checking if #{filename} was last posted..."
    file = query_data("dupes", source)

    cond do
      file == nil ->
        store_data("dupes", source, filename)
        false
      file != filename ->
        store_data("dupes", source, filename)
        false
      file == filename -> true
      true -> nil
    end
  end

  def is_image?(url) do
    Logger.log :info, "Checking if #{url} is an image..."
    image_types = [".jpg", ".jpeg", ".gif", ".png", ".mp4"]
    Enum.member?(image_types, Path.extname(url))
  end

  def titlecase(title, mod) do
    words = title |> String.split(mod)

    for word <- words do
      word |> String.capitalize
    end |> Enum.join(" ")
  end

  def store_data(table, key, value) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])

    :dets.insert(table, {key, value})
    :dets.close(table)
    :ok
  end

  def query_data(table, key) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    result = :dets.lookup(table, key)

    response =
      case result do
        [{_, value}] -> value
        [] -> nil
      end

    :dets.close(table)
    response
  end

  def query_all_data(table) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    result = :dets.match_object(table, {:"$1", :"$2"})

    response =
      case result do
        [] -> nil
        values -> values
      end

    :dets.close(table)
    response
  end

  def delete_data(table, key) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    response = :dets.delete(table, key)

    :dets.close(table)
    response
  end
end
