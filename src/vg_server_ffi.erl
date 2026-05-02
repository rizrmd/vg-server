-module(vg_server_ffi).
-export([get_env/1, timestamp_ms/0, generate_token/0, generate_anonymous_player/0,
         read_file/1, write_file/2, ensure_dir/1,
         read_binary_file/1, write_binary_file/2, file_exists/1]).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

timestamp_ms() ->
    erlang:system_time(millisecond).

generate_token() ->
    Bytes = crypto:strong_rand_bytes(32),
    list_to_binary(lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bytes])).

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

write_file(Path, Content) ->
    case file:write_file(Path, Content) of
        ok -> {ok, nil};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

ensure_dir(Path) ->
    Dir = binary_to_list(Path),
    case filelib:ensure_dir(Dir ++ "/.") of
        ok -> {ok, nil};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

read_binary_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

write_binary_file(Path, Data) ->
    case file:write_file(Path, Data) of
        ok -> {ok, nil};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

file_exists(Path) ->
    filelib:is_regular(Path).

generate_anonymous_player() ->
    Adjectives = [<<"Swift">>, <<"Mystic">>, <<"Shadow">>, <<"Golden">>, <<"Fierce">>,
                  <<"Silent">>, <<"Crimson">>, <<"Storm">>, <<"Ember">>, <<"Frost">>,
                  <<"Thunder">>, <<"Crystal">>, <<"Rogue">>, <<"Noble">>, <<"Ancient">>],
    Nouns = [<<"Fox">>, <<"Wolf">>, <<"Dragon">>, <<"Phoenix">>, <<"Hawk">>,
             <<"Bear">>, <<"Tiger">>, <<"Raven">>, <<"Lion">>, <<"Falcon">>,
             <<"Viper">>, <<"Panther">>, <<"Griffin">>, <<"Sphinx">>, <<"Hydra">>],
    Random = rand:uniform(15),
    Adj = lists:nth(Random, Adjectives),
    Noun = lists:nth(Random, Nouns),
    Num = rand:uniform(99),
    PlayerId = list_to_binary(io_lib:format("anon_~6.6.0b", [rand:uniform(999999)])),
    DisplayName = list_to_binary(io_lib:format("~s~s~2.2.0b", [Adj, Noun, Num])),
    #{player_id => PlayerId, display_name => DisplayName}.
