defmodule DiscordSlate.Commands.Announce do
  import Din.Module
  import DiscordSlate.Util
  alias Din.Resources.{Channel, Guild}

  def announce(data) do
    db = query_data(:guilds, data.guild_id)
    member = if data.game && data.game.type do
      Guild.get_member(data.guild_id, data.user.id)
    else
      nil
    end
    
    if data.game && data.game.type do      
      case data.game.type do
        0 -> remove_streamer(data.guild_id, data.user.id)
        1 ->
          {rate, _} = ExRated.check_rate({data.guild_id, data.user.id}, 3_600_000, 1)

          case rate do
            :ok ->
              log_chan = db.log
              stream_title = data.game.name
              stream_url = data.game.url
              twitch_username = data.game.url
              |> String.split("/")
              |> List.last

              stream_list = case query_data(:streams, data.guild_id) do
                nil -> []
                streams -> streams
              end

              recently_mentioned? = Enum.member?(stream_list, data.user.id)
              good_title? = ~r/1..%|any%|low%|attempts?|de-?rust(ing)?|ILs?|individual levels?|learning|planning|practice|practicing|races?|routing|rtas?|runs?|speedruns?|TAS(ing)?|\[srl\]/i
              |> Regex.match?(stream_title)

              bad_title? = ~r/blind|casual|design(ing)?|let's plays?|\[nosrl\]/i
              |> Regex.match?(stream_title)

              if !recently_mentioned? && good_title? && !bad_title? do
                twitch_user = "https://api.twitch.tv/kraken/users?login=#{twitch_username}"
                headers = %{
                  "Accept" => "application/vnd.twitchtv.v5+json",
                  "Client-ID" => "#{Application.get_env(:discord_slate, :twitch_client_id)}"
                }

                request = HTTPoison.get!(twitch_user, headers)
                response = Poison.Parser.parse!((request.body), keys: :atoms)
                user = response.users |> List.first

                user_channel = "https://api.twitch.tv/kraken/channels/#{user._id}"
                user_info_request = HTTPoison.get!(user_channel, headers)
                user_info_response = Poison.Parser.parse!(user_info_request.body, keys: :atoms)

                if user_info_response.game == "The Legend of Zelda: Breath of the Wild" do
                  store_data("streams", data.guild_id, stream_list ++ [data.user.id])
                  message = "**#{member.user.username}** is now live on Twitch!"

                  Channel.create_message log_chan, message, embed: %{
                    color: 0x4b367c,
                    title: "#{twitch_username} playing The Legend of Zelda: Breath of the Wild",
                    url: "#{stream_url}",
                    description: "#{stream_title}",
                    thumbnail: %{url: "#{user.logo}"},
                    timestamp: "#{DateTime.utc_now() |> DateTime.to_iso8601()}"
                  }
                end
              end
            :error -> nil
          end
        _ -> nil
      end
    end

    unless data.game, do: remove_streamer(data.guild_id, data.user.id)
  end

  defp remove_streamer(guild_id, user_id) do
    stream_list = query_data(:streams, guild_id)

    stream_list = case stream_list do
      nil -> []
      streams -> streams
    end

    if Enum.member?(stream_list, user_id) do
      store_data(:streams, guild_id, stream_list -- [user_id])
    end
  end

  def set_log_channel(data) do
    guild_id = Channel.get(data.channel_id).guild_id
    db = query_data(:guilds, guild_id)

    db = Map.put(db, :log, data.channel_id)
    store_data(:guilds, guild_id, db)
    reply "Okay, I will announce streams here!"
  end

  def del_log_channel(data) do
    guild_id = Channel.get(data.channel_id).guild_id
    db = query_data(:guilds, guild_id)

    db = Map.put(db, :log, nil)
    store_data(:guilds, guild_id, db)
    reply "Okay, I will no longer announce streams."
  end

  def test_announce(data) do
    test_data = data
    |> Map.put(:game, %{type: 1, name: "Test Announcement Speedrun", url: "https://twitch.tv/rekyuus"})
    |> Map.put(:guild_id, Channel.get(data.channel_id).guild_id)
    |> Map.put(:user, data.author)

    announce(test_data)
  end
end
